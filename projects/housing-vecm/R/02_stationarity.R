suppressPackageStartupMessages({ library(urca); library(purrr); library(tibble) })

# ADF (тип по AIC) + KPSS для каждого ряда: уровни и первые разности.
unit_root_table <- function(mts) {
  purrr::map_dfr(colnames(mts), function(v) {
    x <- na.omit(mts[, v]); dx <- diff(x)
    adf  <- function(z) { t <- ur.df(z, type = "drift", selectlags = "AIC")
                          c(stat = t@teststat[1], cv5 = t@cval[1, "5pct"]) }
    kpss <- function(z) { t <- ur.kpss(z, type = "mu")
                          c(stat = t@teststat, cv5 = t@cval[, "5pct"]) }
    a0 <- adf(x); a1 <- adf(dx); k0 <- kpss(x); k1 <- kpss(dx)
    tibble(variable = v,
           adf_level = a0[["stat"]],  adf_level_I0  = a0[["stat"]] < a0[["cv5"]],
           kpss_level = k0[["stat"]], kpss_level_I0 = k0[["stat"]] < k0[["cv5"]],
           adf_diff = a1[["stat"]],   adf_diff_I0   = a1[["stat"]] < a1[["cv5"]],
           kpss_diff = k1[["stat"]],  kpss_diff_I0  = k1[["stat"]] < k1[["cv5"]])
  })
}
