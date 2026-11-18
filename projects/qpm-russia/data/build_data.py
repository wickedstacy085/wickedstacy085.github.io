"""Сборка квартального датасета по России из открытых источников.

Запуск: python data/build_data.py  (из папки projects/qpm-russia)
Результат: data/russia_q.csv

Источники:
  ВВП        Росстат, VVP_kvartal_s-1995-2026.xlsx, лист 10: млрд руб. в ценах 2021 г.,
             с исключением сезонного и календарного факторов
  ИПЦ России BIS WS_LONG_CPI, M.RU.628 (индекс, без сезонной корректировки)
  Ключевая   BIS WS_CBPOL, M.RU (ставка на конец месяца, %)
  USD/RUB    FRED CCUSMA02RUM618N (среднее за месяц)
  ИПЦ США    FRED CPIAUCSL;  ставка ФРС  FRED FEDFUNDS
Месячные ряды усредняются по кварталам; пропуски внутри ряда интерполируются линейно.
"""
import io
import re
import sys
import urllib.request

import openpyxl
import pandas as pd

UA = {"User-Agent": "Mozilla/5.0 (research data download)"}
ROSSTAT_GDP = "https://rosstat.gov.ru/storage/mediabank/VVP_kvartal_s-1995-2026.xlsx"
BIS = "https://stats.bis.org/api/v2/data/dataflow/BIS/{flow}/1.0/{key}?format=csv"
FRED = "https://fred.stlouisfed.org/graph/fredgraph.csv?id={sid}"
QUARTER = {"I": 1, "II": 2, "III": 3, "IV": 4}


def fetch(url: str, tries: int = 3) -> bytes:
    # Росстат отвечает 403 на запросы без браузерного User-Agent; остальным источникам он не нужен.
    headers = UA if "rosstat.gov.ru" in url else {}
    for attempt in range(1, tries + 1):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as r:
                return r.read()
        except OSError:
            if attempt == tries:
                raise


def rosstat_gdp() -> pd.Series:
    wb = openpyxl.load_workbook(io.BytesIO(fetch(ROSSTAT_GDP)), read_only=True, data_only=True)
    rows = list(wb["10"].iter_rows(values_only=True))
    years, quarters, values = rows[2], rows[3], rows[4]
    out, year = {}, None
    for y, q, v in zip(years, quarters, values):
        if y is not None:
            year = int(re.match(r"\d{4}", str(y)).group())
        if v is None or q is None:
            continue
        roman = re.match(r"(IV|I{1,3})", str(q).strip()).group()
        out[pd.Period(f"{year}Q{QUARTER[roman]}", "Q")] = float(v)
    return pd.Series(out, name="gdp")


def monthly_csv(url: str, date_col: str, value_col: str) -> pd.Series:
    df = pd.read_csv(io.BytesIO(fetch(url)))
    s = pd.Series(pd.to_numeric(df[value_col], errors="coerce").values,
                  index=pd.PeriodIndex(df[date_col].astype(str).str[:7], freq="M"))
    s = s.dropna().sort_index()
    # Пропуски внутри ряда (например, ИПЦ США за октябрь 2025 г. не публиковался из-за шатдауна)
    # заполняются линейной интерполяцией между соседними месяцами.
    full = s.reindex(pd.period_range(s.index[0], s.index[-1], freq="M"))
    filled = full.isna().sum()
    if filled:
        print(f"  {url.split('id=')[-1][:40]}: интерполировано месяцев — {filled}")
    return full.interpolate(limit_area="inside")


def to_quarter(s: pd.Series) -> pd.Series:
    g = s.groupby(s.index.asfreq("Q"))
    return g.mean()[g.count() == 3]


def main(out_path: str = "data/russia_q.csv") -> None:
    cols = {
        "gdp": rosstat_gdp(),
        "cpi": to_quarter(monthly_csv(BIS.format(flow="WS_LONG_CPI", key="M.RU.628"), "TIME_PERIOD", "OBS_VALUE")),
        "key_rate": to_quarter(monthly_csv(BIS.format(flow="WS_CBPOL", key="M.RU"), "TIME_PERIOD", "OBS_VALUE")),
        "usdrub": to_quarter(monthly_csv(FRED.format(sid="CCUSMA02RUM618N"), "observation_date", "CCUSMA02RUM618N")),
        "us_cpi": to_quarter(monthly_csv(FRED.format(sid="CPIAUCSL"), "observation_date", "CPIAUCSL")),
        "fed_funds": to_quarter(monthly_csv(FRED.format(sid="FEDFUNDS"), "observation_date", "FEDFUNDS")),
    }
    df = pd.DataFrame(cols).dropna()
    df.index = df.index.to_timestamp()
    df.index.name = "date"
    df.round(4).to_csv(out_path)
    print(f"{out_path}: {len(df)} кварталов, {df.index[0]:%Y-%m} … {df.index[-1]:%Y-%m}")


if __name__ == "__main__":
    main(*sys.argv[1:])
