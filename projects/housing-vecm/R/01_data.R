# Загрузка данных. data/housing.csv: колонка date (YYYY-MM-DD, начало периода) + числовые ряды.
suppressPackageStartupMessages({ library(readr); library(dplyr) })

load_housing <- function(path = "data/housing.csv") {
  if (!file.exists(path)) stop("Нет файла данных: ", path, ". См. data/README.md")
  raw <- readr::read_csv(path, show_col_types = FALSE) |> dplyr::arrange(date)
  stopifnot("date" %in% names(raw), !anyNA(raw))
  d0   <- as.Date(raw$date[1])
  step <- as.numeric(difftime(as.Date(raw$date[2]), d0, units = "days"))
  freq <- if (step > 80) 4 else 12
  per  <- if (freq == 4) (as.integer(format(d0, "%m")) - 1) %/% 3 + 1 else as.integer(format(d0, "%m"))
  ts(as.matrix(raw[-1]), start = c(as.integer(format(d0, "%Y")), per), frequency = freq)
}

# Сезонная корректировка на уровнях: STL, сезонная компонента вычитается (а не делится).
seasonal_adjust <- function(x) {
  fit <- stats::stl(x, s.window = "periodic", robust = TRUE)
  x - fit$time.series[, "seasonal"]
}
