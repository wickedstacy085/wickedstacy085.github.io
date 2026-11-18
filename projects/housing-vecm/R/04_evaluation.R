suppressPackageStartupMessages({ library(forecast); library(vars); library(tibble) })

# Честный out-of-sample: модель оценивается на train, прогноз сравнивается с test.
holdout_compare <- function(y, target = "Index", h = 8) {
  n <- nrow(y); tt <- time(y)
  train <- window(y, end = tt[n - h]); test <- window(y, start = tt[n - h + 1])
  actual <- as.numeric(test[, target])

  f_rw   <- rep(tail(train[, target], 1), h)
  f_arim <- as.numeric(forecast(auto.arima(train[, target]), h = h)$mean)
  f_vecm <- suppressWarnings(fit_vecm(train, r = 1))$var_form |> predict(n.ahead = h) |>
            (\(p) p$fcst[[target]][, "fcst"])()

  metrics <- function(f) c(MAE = mean(abs(actual - f)), RMSE = sqrt(mean((actual - f)^2)))
  res <- rbind(`Random walk` = metrics(f_rw), ARIMA = metrics(f_arim), VECM = metrics(f_vecm))
  out <- tibble::as_tibble(res, rownames = "model")
  out$RMSE_vs_RW <- out$RMSE / out$RMSE[out$model == "Random walk"]
  attr(out, "paths") <- data.frame(time = as.numeric(time(test)), actual,
                                   rw = f_rw, arima = f_arim, vecm = f_vecm)
  out
}
