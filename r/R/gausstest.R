#' Gaussianity tests
#'
#' Bera-Jarque and Kolmogorov-Smirnov-Lilliefors tests of normality for every
#' series and, for more than one series, the multivariate Bera-Jarque test.
#'
#' The Lilliefors p-values are approximate: they are interpolated (and
#' linearly extrapolated, clamped to `[0, 1]`) in the table of critical values
#' of Lilliefors (1967) for p = 0.20, 0.15, 0.10, 0.05 and 0.01.
#'
#' @inheritParams sumstats
#' @return An object of class `tsx_gausstest` with fields `call`, `series`,
#'   `table` (data.frame with columns `series`, `n`, `skewness`, `kurtosis`
#'   (excess), `bj`, `p_bj`, `ksl`, `p_ksl`) and, for more than one series,
#'   `bj_multi` and `p_bj_multi`.
#' @references
#' Jarque, C.M. and Bera, A.K. (1987). A test for normality of observations
#' and regression residuals. *International Statistical Review*, 55, 163-172.
#'
#' Lilliefors, H.W. (1967). On the Kolmogorov-Smirnov test for normality with
#' mean and variance unknown. *Journal of the American Statistical
#' Association*, 62, 399-402.
#' @examples
#' gausstest(airpas)
#' gausstest(log(airpas))
#' @export
gausstest <- function(y, digits = 4, names = NULL) {
  y <- as_tsx_matrix(y, names)
  m <- ncol(y)
  skew <- kurt <- n <- d <- pd <- numeric(m)
  for (i in seq_len(m)) {
    zi <- y[!is.na(y[, i]), i]
    n[i] <- length(zi)
    skew[i] <- tsx_skewness(zi)
    kurt[i] <- tsx_kurtosis(zi) - 3
    d[i] <- tsx_lilliefors_stat(zi)
    pd[i] <- tsx_lilliefors_p(d[i], n[i])
  }
  bj <- n / 6 * (skew^2 + kurt^2 / 4)
  tab <- data.frame(series = colnames(y), n = n, skewness = skew,
                    kurtosis = kurt, bj = bj,
                    p_bj = stats::pchisq(bj, 2, lower.tail = FALSE),
                    ksl = d, p_ksl = pd, stringsAsFactors = FALSE)
  bj_multi <- p_bj_multi <- NULL
  if (m > 1) {
    bj_multi <- sum(bj)
    p_bj_multi <- stats::pchisq(bj_multi, 2 * m, lower.tail = FALSE)
  }
  tsx_result("gausstest", call = list(digits = digits), series = colnames(y),
             table = tab, bj_multi = bj_multi, p_bj_multi = p_bj_multi)
}

# Kolmogorov-Smirnov statistic against a normal with estimated mean and
# standard deviation: max(D+, D-).
tsx_lilliefors_stat <- function(x) {
  x <- sort(x)
  n <- length(x)
  f <- stats::pnorm(x, mean(x), stats::sd(x))
  max(max(seq_len(n) / n - f), max(f - (seq_len(n) - 1) / n))
}

# Approximate p-value of the Lilliefors test (interpolated in a table of critical values).
tsx_lilliefors_p <- function(d, n) {
  if (n > 30) {
    crit <- c(0.736, 0.768, 0.805, 0.886, 1.031) / sqrt(n)
  } else if (n < 5) {
    return(NA_real_)
  } else {
    crit <- tsx_tables$lillie[n - 4, ]
  }
  tsx_interpol(crit, tsx_tables$lillie_p, d, c(0, 1))
}

#' @export
print.tsx_gausstest <- function(x, digits = x$call$digits, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tab <- x$table[, c("skewness", "kurtosis", "bj", "p_bj", "ksl", "p_ksl")]
  lines <- tsx_format_table(tab, digits, row_names = x$series,
                            col_names = c("Skewness", "Kurtosis(-3)", "Bera-Jarque",
                                          "P-value", "KSLilliefors", "P-value"))
  tsx_cat_block(
    title = "Bera-Jarque and Kolmogorov-Smirnov Lilliefors (KSL) gaussianity tests.",
    notes = c("H0: Distribution is gaussian.", "(Assumptions: Independence)",
              "(Approximate P-value for KSL test)."),
    table = lines)
  if (!is.null(x$bj_multi)) {
    cat("\n")
    tsx_cat_block(table = tsx_format_table(
      data.frame(x$bj_multi, x$p_bj_multi), digits,
      col_names = c("Multivariate Bera-Jarque", "P-value")))
  }
  invisible(x)
}
