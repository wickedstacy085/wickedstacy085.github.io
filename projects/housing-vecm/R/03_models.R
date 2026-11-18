suppressPackageStartupMessages({ library(vars); library(urca); library(forecast) })

fit_var <- function(y, lag.max = 4, crit = "SC(n)") {
  p <- VARselect(y, lag.max = lag.max, type = "const")$selection[[crit]]
  VAR(y, p = max(p, 1), type = "const")
}

var_diagnostics <- function(m, lags = 8) {
  list(portmanteau = serial.test(m, lags.pt = lags, type = "PT.asymptotic"),
       breusch_godfrey = serial.test(m, lags.bg = lags, type = "BG"),
       arch = arch.test(m, lags.multi = 5),
       normality = normality.test(m))
}

# Йохансен (trace) + VECM в форме VAR в уровнях для прогнозов и IRF.
fit_vecm <- function(y, lag.max = 4, r = NULL) {
  K  <- max(VARselect(y, lag.max = lag.max, type = "const")$selection[["SC(n)"]], 2)
  jo <- ca.jo(y, type = "trace", ecdet = "const", K = K)
  if (is.null(r)) {
    stat <- rev(jo@teststat); cv <- rev(jo@cval[, "5pct"])
    r <- sum(cumprod(stat > cv))           # последовательная процедура Йохансена
  }
  r_test <- r
  if (r == 0) {
    warning("Йохансен: коинтеграция не найдена на 5%; VECM оценивается с r = 1 только для сравнения")
    r <- 1
  }
  if (r >= ncol(y)) r <- ncol(y) - 1
  list(johansen = jo, r = r, r_test = r_test, K = K,
       ecm = cajorls(jo, r = r),           # α (скорость корректировки) и β
       var_form = vec2var(jo, r = r))
}

# Половина отклонения от равновесия закрывается за ln(0.5)/ln(1+alpha) периодов (кварталов).
half_life <- function(alpha) log(0.5) / log(1 + alpha)
