suppressPackageStartupMessages({ library(vars); library(urca); library(forecast) })

fit_var <- function(y, lag.max = 12, crit = "SC(n)") {
  p <- VARselect(y, lag.max = lag.max, type = "const")$selection[[crit]]
  VAR(y, p = max(p, 1), type = "const")
}

var_diagnostics <- function(m, lags = 12) {
  list(portmanteau = serial.test(m, lags.pt = lags, type = "PT.asymptotic"),
       breusch_godfrey = serial.test(m, lags.bg = lags, type = "BG"),
       arch = arch.test(m, lags.multi = 5),
       normality = normality.test(m))
}

# Йохансен (trace) + VECM в форме VAR в уровнях для прогнозов и IRF.
fit_vecm <- function(y, lag.max = 12, r = NULL) {
  K  <- max(VARselect(y, lag.max = lag.max, type = "const")$selection[["SC(n)"]], 2)
  jo <- ca.jo(y, type = "trace", ecdet = "const", K = K)
  if (is.null(r)) {
    stat <- rev(jo@teststat); cv <- rev(jo@cval[, "5pct"])
    r <- sum(cumprod(stat > cv))           # последовательная процедура Йохансена
  }
  if (r == 0) stop("Коинтеграция не найдена на 5% — используйте VAR в разностях")
  if (r >= ncol(y)) stop("Полный ранг: ряды стационарны в уровнях — используйте VAR в уровнях")
  list(johansen = jo, r = r, K = K,
       ecm = cajorls(jo, r = r),           # α (скорость корректировки) и β
       var_form = vec2var(jo, r = r))
}

# Половина отклонения от равновесия закрывается за ln(0.5)/ln(1+alpha) мес.
half_life <- function(alpha) log(0.5) / log(1 + alpha)
