#' Sample autocorrelation and partial autocorrelation functions
#'
#' Univariate sample ACF and PACF of one series, with their standard errors
#' (Bartlett for the ACF, \eqn{1/\sqrt{T}} for the PACF), the Ljung-Box
#' portmanteau test on the ACF and the Monti (1994) test on the PACF.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param ncoef Number of lags. Default `min(38, ceiling(T / 4 / m * 2))`,
#'   limited to `T - 5`.
#' @param s Seasonal period, only used to highlight the seasonal lags in the
#'   plot.
#' @param npar Number of estimated parameters when `y` is a set of
#'   residuals; the degrees of freedom of the portmanteau tests are `lag - npar`.
#' @param series Series to analyse (index or name).
#' @param names Optional names of the series.
#' @return An object of class `tsx_vident` with fields `call`, `series`
#'   (name of the series analysed) and `table`, a data.frame with columns
#'   `lag`, `acf`, `se_acf`, `q_lb`, `p_lb`, `pacf`, `se_pacf`, `q_mt`, `p_mt`.
#' @references
#' Ljung, G.M. and Box, G.E.P. (1978). On a measure of lack of fit in time
#' series models. *Biometrika*, 65, 297-303.
#'
#' Monti, A.C. (1994). A proposal for a residual autocorrelation test in
#' linear models. *Biometrika*, 81, 776-780.
#' @examples
#' r <- vident(vdif(log(airpas), c(1, 1), c(1, 12)))
#' r
#' plot(r)
#' @export
vident <- function(y, ncoef = NULL, s = 12, npar = 0, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  if (is.null(ncoef)) ncoef <- min(38, ceiling(n / 4 / m * 2))
  ncoef <- min(tsx_check_int(ncoef, "ncoef"), n - 5)
  if (ncoef < 1) stop("Too few data points.", call. = FALSE)
  i <- tsx_series_index(series, y)[1]
  r <- tsx_acf_pacf(y[, i], ncoef, npar)
  tab <- data.frame(lag = seq_len(ncoef), acf = r$sacf, se_acf = r$se_acf,
                    q_lb = r$q, p_lb = r$p_q, pacf = r$spacf,
                    se_pacf = r$se_pacf, q_mt = r$q_mt, p_mt = r$p_q_mt)
  tsx_result("vident", call = list(ncoef = ncoef, s = s, npar = npar, series = i),
             series = colnames(y)[i], table = tab)
}

#' @export
print.tsx_vident <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  t <- x$table
  lines <- tsx_format_table(
    data.frame(t$lag, t$acf, tsx_signif_marks(t$acf / t$se_acf), t$q_lb, t$p_lb,
               t$pacf, tsx_signif_marks(t$pacf / t$se_pacf), t$q_mt, t$p_mt),
    c(0, digits, 0, digits, digits, digits, 0, digits, digits),
    col_names = c("Lag", "SACF", "", "LB", "P-value", "SPACF", "", "MT", "P-value"))
  tsx_cat_block(title = "Univariate Sample ACF and PACF",
                notes = c("LB: Ljung-Box Test", "MT: Monti (1994) Test",
                          "H0: Process is white noise", paste("Series", x$series)),
                table = lines)
  invisible(x)
}

#' @export
plot.tsx_vident <- function(x, ...) {
  t <- x$table
  tsx_plot_correlogram(t$lag, cbind(t$acf, t$pacf), cbind(t$se_acf, t$se_pacf),
                       x$call$s,
                       c(paste0("Series ", x$series, ": Univariate Sample Autocorrelation Function"),
                         paste0("Series ", x$series, ": Univariate Sample Partial Autocorrelation Function")))
  invisible(x)
}

# Correlogram bars with 2 standard error bands, seasonal lags
# drawn in red dotted lines.
tsx_plot_correlogram <- function(lags, values, se, s, titles) {
  k <- ncol(values)
  op <- graphics::par(mfrow = c(k, 1), mar = c(4, 4, 2.5, 1))
  on.exit(graphics::par(op))
  for (j in seq_len(k)) {
    v <- values[, j]
    band <- 2 * se[, j]
    ylim <- range(c(v, band, -band), na.rm = TRUE) + c(-0.05, 0.05)
    graphics::plot(NA, xlim = c(min(lags) - 1, max(lags) + 1), ylim = ylim,
                   xlab = if (j == k) "Lags" else "", ylab = "Correlation",
                   main = titles[j], cex.main = 0.9)
    seas <- (lags %% s) == 0
    if (any(!seas)) graphics::segments(lags[!seas], 0, lags[!seas], v[!seas], col = "blue")
    if (any(seas)) graphics::segments(lags[seas], 0, lags[seas], v[seas], col = "red", lty = 3)
    graphics::abline(h = 0, col = "blue")
    graphics::lines(lags, band, col = "red", lty = 3)
    graphics::lines(lags, -band, col = "red", lty = 3)
  }
}
