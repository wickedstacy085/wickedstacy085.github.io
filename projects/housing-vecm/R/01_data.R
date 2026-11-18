# Загрузка и подготовка данных. Ожидается data/housing.csv:
# колонка date (YYYY-MM-DD, первое число месяца) + числовые ряды.
suppressPackageStartupMessages({ library(readr); library(dplyr) })

load_housing <- function(path = here::here("projects/housing-vecm/data/housing.csv"),
                         start = c(2005, 10)) {
  if (!file.exists(path)) {
    alt <- file.path(dirname(path), "proj2.xlsx")       # исходный файл диплома как есть
    if (!file.exists(alt)) stop("Нет файла данных: ", path, " или ", alt, ". См. data/README.md")
    path <- alt
  }
  raw <- if (grepl("\\.xlsx?$", path, ignore.case = TRUE)) {
    readxl::read_excel(path)
  } else {
    readr::read_csv(path, show_col_types = FALSE)
  }
  if ("Data" %in% names(raw) && !"date" %in% names(raw)) raw <- dplyr::rename(raw, date = Data)
  stopifnot("date" %in% names(raw))
  raw <- dplyr::arrange(raw, date)
  if (anyNA(raw)) {
    warning("Есть пропуски — заполняю линейной интерполяцией (zoo::na.approx)")
    raw[-1] <- lapply(raw[-1], zoo::na.approx, na.rm = FALSE)
  }
  ts(as.matrix(raw[-1]), start = start, frequency = 12)
}

# Сезонная корректировка на уровнях: STL, сезонная компонента вычитается.
seasonal_adjust <- function(x) {
  fit <- stats::stl(x, s.window = "periodic", robust = TRUE)
  x - fit$time.series[, "seasonal"]
}
