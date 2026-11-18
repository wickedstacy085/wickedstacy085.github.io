"""Малая полуструктурная модель (QPM) российской экономики.

Структура по Berg, Karam, Laxton (2006), "A Practical Model-Based Approach to Monetary Policy
Analysis", IMF WP/06/80. Все переменные — отклонения от равновесия (гэпы), в процентах;
инфляция и ставки — в годовом выражении.

    IS:       y_t  = b_lead*y_{t+1} + b_lag*y_{t-1} - b_rmci*(b_rr*r_t - (1-b_rr)*z_t) + e^y
    Филлипс:  pi_t = a_lead*pi_{t+1} + (1-a_lead)*pi_{t-1} + a_rmc*(a_y*y_t + (1-a_y)*z_t) + e^pi
    Ставка:   i_t  = g_lag*i_{t-1} + (1-g_lag)*((1+g_pi)*pi_{t+1} + g_y*y_t) + e^i
    UIP:      z_t  = e_lead*z_{t+1} + (1-e_lead)*z_{t-1} - r_t/4 + e^z
    Фишер:    r_t  = i_t - pi_{t+1}

y — разрыв выпуска, pi — отклонение квартальной инфляции (SAAR) от цели 4%, i — отклонение ключевой
ставки от нейтральной, r — разрыв реальной ставки, z — разрыв реального курса (рост = ослабление рубля).
"""
from dataclasses import dataclass, field

import numpy as np
import pandas as pd
from statsmodels.tsa.filters.hp_filter import hpfilter
from statsmodels.tsa.seasonal import STL

VARS = ["y", "pi", "i", "z", "r"]
SHOCKS = ["e_y", "e_pi", "e_i", "e_z"]
TARGET = 4.0     # цель Банка России по инфляции, % г/г
R_NEUTRAL = 3.0  # допущение о нейтральной реальной ставке, %


@dataclass
class Params:
    # Калибровка: значения в диапазонах Berg, Karam, Laxton (2006) для открытой экономики
    # с плавающим курсом. Параметры не оценивались на данных.
    b_lead: float = 0.10
    b_lag: float = 0.75
    b_rmci: float = 0.15
    b_rr: float = 0.60
    a_lead: float = 0.30
    a_rmc: float = 0.20
    a_y: float = 0.70
    g_lag: float = 0.70
    g_pi: float = 1.50
    g_y: float = 0.50
    e_lead: float = 0.50
    shock_sd: dict = field(default_factory=lambda: {"e_y": 1.0, "e_pi": 1.0, "e_i": 1.0, "e_z": 1.0})


def system_matrices(p: Params):
    """Матрицы модели в форме  A*x_{t-1} + B*x_t + C*E_t x_{t+1} + D*e_t = 0."""
    n, k = len(VARS), len(SHOCKS)
    ix = {v: j for j, v in enumerate(VARS)}
    A, B, C = (np.zeros((n, n)) for _ in range(3))
    D = np.zeros((n, k))
    y, pi, i, z, r = (ix[v] for v in VARS)

    # IS
    B[0, y] = 1; C[0, y] = -p.b_lead; A[0, y] = -p.b_lag
    B[0, r] = p.b_rmci * p.b_rr; B[0, z] = -p.b_rmci * (1 - p.b_rr); D[0, 0] = -1
    # Филлипс
    B[1, pi] = 1; C[1, pi] = -p.a_lead; A[1, pi] = -(1 - p.a_lead)
    B[1, y] = -p.a_rmc * p.a_y; B[1, z] = -p.a_rmc * (1 - p.a_y); D[1, 1] = -1
    # Правило ставки
    B[2, i] = 1; A[2, i] = -p.g_lag
    C[2, pi] = -(1 - p.g_lag) * (1 + p.g_pi); B[2, y] = -(1 - p.g_lag) * p.g_y; D[2, 2] = -1
    # UIP в реальном выражении
    B[3, z] = 1; C[3, z] = -p.e_lead; A[3, z] = -(1 - p.e_lead); B[3, r] = 0.25; D[3, 3] = -1
    # Фишер
    B[4, r] = 1; B[4, i] = -1; C[4, pi] = 1
    return A, B, C, D


def solve(p: Params, tol: float = 1e-12, max_iter: int = 10_000):
    """Решение x_t = P x_{t-1} + Q e_t итерацией P <- -(B + C P)^{-1} A (Binder, Pesaran 1995).

    Возвращает P, Q и проверку: невязку матричного уравнения и спектральный радиус P.
    """
    A, B, C, D = system_matrices(p)
    P = np.zeros_like(A)
    for it in range(max_iter):
        P_new = -np.linalg.solve(B + C @ P, A)
        if np.max(np.abs(P_new - P)) < tol:
            P = P_new
            break
        P = P_new
    else:
        raise RuntimeError("Итерация не сошлась: проверьте параметры (нет устойчивого решения)")
    Q = -np.linalg.solve(B + C @ P, D)
    residual = np.max(np.abs(A + B @ P + C @ P @ P))
    radius = np.max(np.abs(np.linalg.eigvals(P)))
    if residual > 1e-8 or radius >= 1:
        raise RuntimeError(f"Решение некорректно: невязка {residual:.1e}, спектральный радиус {radius:.3f}")
    return P, Q, {"iterations": it + 1, "residual": residual, "spectral_radius": radius}


def irf(p: Params, shock: str, size: float = 1.0, horizon: int = 16) -> pd.DataFrame:
    """Импульсный отклик на разовый шок величиной size (в п.п.) в квартале 0."""
    P, Q, _ = solve(p)
    e = np.zeros(len(SHOCKS)); e[SHOCKS.index(shock)] = size
    x = np.zeros(len(VARS)); path = []
    for t in range(horizon + 1):
        x = P @ x + (Q @ e if t == 0 else 0)
        path.append(x.copy())
    return pd.DataFrame(path, columns=VARS)


def simulate_from(p: Params, x0: np.ndarray, horizon: int = 8) -> pd.DataFrame:
    """Детерминированная траектория без новых шоков из начального состояния x0."""
    P, _, _ = solve(p)
    x, path = np.asarray(x0, float), []
    for _ in range(horizon):
        x = P @ x
        path.append(x.copy())
    return pd.DataFrame(path, columns=VARS)


def load_data(path: str = "data/russia_q.csv") -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["date"]).set_index("date")
    df.index = pd.PeriodIndex(df.index, freq="Q")
    return df


def build_gaps(df: pd.DataFrame, lam: float = 1600) -> pd.DataFrame:
    """Наблюдаемые гэпы: HP-фильтр (λ = 1600) для выпуска, реальной ставки и реального курса.

    ИПЦ России очищается от сезонности STL (период 4) до расчёта квартальной инфляции.
    """
    out = pd.DataFrame(index=df.index)
    log_gdp = 100 * np.log(df["gdp"])
    out["y"] = hpfilter(log_gdp, lamb=lam)[0]

    log_cpi = 100 * np.log(df["cpi"])
    cpi_sa = log_cpi - STL(log_cpi, period=4, robust=True).fit().seasonal
    out["infl"] = 4 * cpi_sa.diff()                  # квартальная инфляция, SAAR
    out["infl_yoy"] = log_cpi.diff(4)                # г/г, для сравнения с целью
    out["pi"] = out["infl"] - TARGET

    out["key_rate"] = df["key_rate"]
    # Реальная ставка: ключевая минус инфляция г/г (квартальная SAAR слишком шумная).
    # Нейтральная реальная ставка — допущение R_NEUTRAL, а не оценка: HP-тренд реальной ставки
    # на конце выборки уходит выше 10% из-за эффекта края фильтра.
    out["r"] = df["key_rate"] - out["infl_yoy"] - R_NEUTRAL
    out["i"] = df["key_rate"] - (R_NEUTRAL + TARGET)

    log_rer = 100 * np.log(df["usdrub"] * df["us_cpi"] / df["cpi"])
    out["z"] = hpfilter(log_rer, lamb=lam)[0]
    return out.dropna(subset=["infl"])
