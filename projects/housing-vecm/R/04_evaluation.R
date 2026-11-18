suppressPackageStartupMessages({ library(forecast); library(vars); library(tibble) })

# Прогноз целевой переменной из VECM (r = 1) в форме VAR в уровнях.
vecm_forecast <- function(y, target, h) {
  m <- suppressWarnings(fit_vecm(y, r = 1))
  as.numeric(predict(m$var_form, n.ahead = h)$fcst[[target]][, "fcst"])
}

# Набор сравниваемых моделей: имя -> функция(train, target, h) -> прогноз длины h.
default_models <- list(
  `Random walk` = function(tr, target, h) rep(as.numeric(tail(tr[, target], 1)), h),
  `ARIMA`       = function(tr, target, h) as.numeric(forecast(auto.arima(tr[, target]), h = h)$mean),
  `VECM: цены + безработица` =
    function(tr, target, h) vecm_forecast(tr[, c(target, "Unemployment")], target, h),
  `VECM: + ставка по ипотеке` =
    function(tr, target, h) vecm_forecast(tr[, c(target, "Unemployment", "MRate")], target, h)
)

# Одна отложенная выборка: оценка на всём, кроме последних h наблюдений.
holdout_compare <- function(y, target = "Index", h = 8, models = default_models) {
  n <- nrow(y); tt <- time(y)
  train  <- window(y, end = tt[n - h])
  actual <- as.numeric(y[(n - h + 1):n, target])
  paths  <- lapply(models, function(f) f(train, target, h))
  rmse   <- sapply(paths, function(f) sqrt(mean((actual - f)^2)))
  mae    <- sapply(paths, function(f) mean(abs(actual - f)))
  out <- tibble(model = names(models), MAE = mae, RMSE = rmse,
                RMSE_vs_RW = rmse / rmse[["Random walk"]])
  attr(out, "paths") <- data.frame(time = as.numeric(tt[(n - h + 1):n]), actual, paths, check.names = FALSE)
  out
}

# Скользящее начало прогноза (expanding window): модель переоценивается в каждой точке,
# прогноз на 1..h шагов сравнивается с фактом. Надёжнее одной отложенной выборки.
rolling_compare <- function(y, target = "Index", h = 4, first_origin = 2015.75,
                            models = default_models) {
  tt <- as.numeric(time(y)); n <- nrow(y)
  origins <- which(tt >= first_origin & seq_len(n) <= n - h)
  rows <- list()
  for (o in origins) {
    train  <- window(y, end = tt[o])
    actual <- as.numeric(y[(o + 1):(o + h), target])
    for (m in names(models)) {
      f <- tryCatch(models[[m]](train, target, h), error = function(e) rep(NA_real_, h))
      rows[[length(rows) + 1]] <- data.frame(origin = tt[o], model = m, horizon = seq_len(h),
                                             error = actual - f)
    }
  }
  do.call(rbind, rows)
}

# Сводка RMSE по моделям для заданного горизонта и периода начала прогноза.
rolling_rmse <- function(err, horizon = NULL, from = -Inf, to = Inf) {
  e <- err[err$origin >= from & err$origin < to, ]
  if (!is.null(horizon)) e <- e[e$horizon == horizon, ]
  agg <- aggregate(error ~ model, data = e, FUN = function(x) sqrt(mean(x^2, na.rm = TRUE)))
  names(agg)[2] <- "RMSE"
  agg$RMSE_vs_RW <- agg$RMSE / agg$RMSE[agg$model == "Random walk"]
  agg[order(agg$RMSE), ]
}
