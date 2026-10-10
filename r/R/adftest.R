#' Augmented Dickey-Fuller unit root tests
#'
#' ADF regressions of \eqn{z_t} on \eqn{z_{t-1}}, \eqn{p} lagged differences
#' and the deterministic terms of three models: no constant and no trend,
#' constant, and constant plus linear trend. The tests are the t statistics
#' of \eqn{H_0: \rho = 1} and the F statistics \eqn{\Phi_1} (\eqn{\rho = 1}
#' and no constant) and \eqn{\Phi_3} (\eqn{\rho = 1} and no trend).
#'
#' P-values are approximate, interpolated in the tables of Dickey and Fuller
#' (see [adfcritical()]).
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param lags Number(s) of lagged differences included in the regressions.
#'   Default: `1:min(floor(sqrt(T)), 20)` for one series and
#'   `min(floor(sqrt(T)), 20)` for several series. If the largest lag
#'   exceeds `T / 2` the test is computed only for `floor(T / 2)` lags.
#' @param names Optional names of the series.
#' @return An object of class `tsx_adftest` with fields `call`, `series`, `n`
#'   (sample size used for the p-values) and three data.frames, one row per
#'   series and lag:
#'   * `none`: `series`, `lag`, `rho`, `t`, `p_t`,
#'   * `const`: as `none` plus `const`, `t_const`, `f` (\eqn{\Phi_1}), `p_f`,
#'   * `trend`: as `const` plus `trend`, `t_trend`, with `f` being
#'     \eqn{\Phi_3}.
#' @references
#' Dickey, D.A. and Fuller, W.A. (1979). Distribution of the estimators for
#' autoregressive time series with a unit root. *Journal of the American
#' Statistical Association*, 74, 427-431.
#'
#' Dickey, D.A. and Fuller, W.A. (1981). Likelihood ratio statistics for
#' autoregressive time series with a unit root. *Econometrica*, 49, 1057-1072.
#'
#' Said, S.E. and Dickey, D.A. (1984). Testing for unit roots in
#' autoregressive-moving average models of unknown order. *Biometrika*, 71,
#' 599-607.
#' @examples
#' adftest(log(airpas), lags = 1:4)
#' @export
adftest <- function(y, lags = NULL, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  lags <- tsx_unitroot_lags(lags, n, m)
  none <- const <- trend <- NULL
  for (i in seq_len(m)) {
    for (p in lags) {
      d <- tsx_adf_design(y[, i], p)
      # No constant, no trend
      r0 <- tsx_adf_ols(d$y, d$x[, c(1, seq_len(p) + 3), drop = FALSE])
      none <- rbind(none, data.frame(series = colnames(y)[i], lag = p,
                                     rho = r0$beta[1], t = (r0$beta[1] - 1) / r0$se[1]))
      # Constant
      r1 <- tsx_adf_ols(d$y, d$x[, c(1, 2, seq_len(p) + 3), drop = FALSE])
      vv <- c(r1$beta[1] - 1, r1$beta[2])
      f1 <- drop(t(vv) %*% solve(r1$cov[1:2, 1:2]) %*% vv) / 2
      const <- rbind(const, data.frame(series = colnames(y)[i], lag = p,
                                       rho = r1$beta[1], t = (r1$beta[1] - 1) / r1$se[1],
                                       const = r1$beta[2], t_const = r1$beta[2] / r1$se[2],
                                       f = f1))
      # Constant and trend
      r2 <- tsx_adf_ols(d$y, d$x)
      vv <- c(r2$beta[1] - 1, r2$beta[3])
      f3 <- drop(t(vv) %*% solve(r2$cov[c(1, 3), c(1, 3)]) %*% vv) / 2
      trend <- rbind(trend, data.frame(series = colnames(y)[i], lag = p,
                                       rho = r2$beta[1], t = (r2$beta[1] - 1) / r2$se[1],
                                       const = r2$beta[2], t_const = r2$beta[2] / r2$se[2],
                                       trend = r2$beta[3], t_trend = r2$beta[3] / r2$se[3],
                                       f = f3))
    }
  }
  none$p_t <- adfcritical(none$t, n, "t_none")
  const$p_t <- adfcritical(const$t, n, "t_const")
  const$p_f <- adfcritical(const$f, n, "f_const")
  trend$p_t <- adfcritical(trend$t, n, "t_trend")
  trend$p_f <- adfcritical(trend$f, n, "f_trend")
  const <- const[, c("series", "lag", "rho", "t", "p_t", "const", "t_const", "f", "p_f")]
  trend <- trend[, c("series", "lag", "rho", "t", "p_t", "const", "t_const",
                     "trend", "t_trend", "f", "p_f")]
  rownames(none) <- rownames(const) <- rownames(trend) <- NULL
  tsx_result("adftest", call = list(lags = lags), series = colnames(y), n = n,
             none = none, const = const, trend = trend)
}

# Default and correction of the lags of the unit root tests (adftest(),
# vphillips(), johansentest()).
tsx_unitroot_lags <- function(lags, n, m) {
  if (is.null(lags) || length(lags) == 0) {
    lags <- if (m == 1) seq_len(min(floor(sqrt(n)), 20)) else min(floor(sqrt(n)), 20)
  }
  lags <- as.integer(round(lags))
  if (max(lags) > n / 2) lags <- as.integer(floor(n / 2))
  lags
}

# Design of the ADF regressions with p lagged differences:
# columns z(t-1), constant, trend, dz(t-1), ..., dz(t-p). Rows with missing
# values are removed.
tsx_adf_design <- function(z, p) {
  n <- length(z)
  dz <- diff(z)
  rows <- (p + 2):n
  x <- cbind(z[rows - 1], 1, seq_along(rows))
  for (j in seq_len(p)) x <- cbind(x, dz[rows - 1 - j])
  yy <- z[rows]
  ok <- stats::complete.cases(x) & !is.na(yy)
  list(y = yy[ok], x = x[ok, , drop = FALSE])
}

tsx_adf_ols <- function(y, x) {
  if (nrow(x) <= ncol(x)) {
    stop("Too many lags for the sample size; reduce 'lags'.", call. = FALSE)
  }
  r <- tsx_ols(y, x)
  s2 <- r$sse / (nrow(x) - ncol(x))
  cov <- s2 * r$ixx
  list(beta = as.vector(r$beta), cov = cov, se = sqrt(diag(cov)), e = as.vector(r$e),
       sse = r$sse, s2 = s2)
}

#' Approximate p-values of Dickey-Fuller statistics
#'
#' Interpolates the p-value of Dickey-Fuller t and F statistics in the tables
#' of Fuller (1976) and Dickey and Fuller (1981). The
#' critical values are first interpolated linearly in the sample size
#' (clamped to 25; sizes above 500 use the asymptotic row), then the p-value
#' is interpolated linearly in the statistic. Outside the tables the p-value
#' is set to 0 or 1.
#'
#' @param x Vector of statistics.
#' @param n Sample size.
#' @param table One of `"t_none"`, `"t_const"`, `"t_trend"` (t statistics
#'   without deterministic terms, with constant, with constant and trend),
#'   `"f_const"` (\eqn{\Phi_1}) or `"f_trend"` (\eqn{\Phi_3}).
#' @return Vector of p-values.
#' @examples
#' adfcritical(c(-3.5, -2, 0), 100, "t_const")
#' @export
adfcritical <- function(x, n, table = c("t_none", "t_const", "t_trend", "f_const",
                                        "f_trend")) {
  table <- match.arg(table)
  tab <- tsx_tables$adf[[table]]
  sizes <- tsx_tables$adf_sizes
  is_t <- substr(table, 1, 1) == "t"
  p <- if (is_t) tsx_tables$adf_p_t else tsx_tables$adf_p_f
  if (n > 500) n <- 1000
  if (n < 25) n <- 25
  # Points (critical value, sample size, probability) in column-major order
  px <- as.vector(tab)
  py <- rep(sizes, times = length(p))
  pp <- rep(p, each = length(sizes))
  tri <- tsx_tables$adf_tri[[table]]
  vapply(x, function(xi) {
    if (is.na(xi)) return(NA_real_)
    v <- tsx_tri_interp(px, py, pp, tri, xi, n)
    if (!is.na(v)) return(v)
    if (is_t) return(if (xi > -0.5) 1 else 0)
    if (xi > 4) 0 else 1
  }, numeric(1))
}

# Linear interpolation on a triangulation: value
# at (x0, y0) from the barycentric coordinates of the containing triangle;
# NA outside the convex hull.
tsx_tri_interp <- function(px, py, pv, tri, x0, y0) {
  for (k in seq_len(nrow(tri))) {
    i <- tri[k, ]
    x1 <- px[i[1]]; y1 <- py[i[1]]
    x2 <- px[i[2]]; y2 <- py[i[2]]
    x3 <- px[i[3]]; y3 <- py[i[3]]
    den <- (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
    w1 <- ((y2 - y3) * (x0 - x3) + (x3 - x2) * (y0 - y3)) / den
    w2 <- ((y3 - y1) * (x0 - x3) + (x1 - x3) * (y0 - y3)) / den
    w3 <- 1 - w1 - w2
    tol <- -1e-10
    if (w1 >= tol && w2 >= tol && w3 >= tol) {
      return(w1 * pv[i[1]] + w2 * pv[i[2]] + w3 * pv[i[3]])
    }
  }
  NA_real_
}

#' @export
print.tsx_adftest <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  multi <- length(unique(x$none$series)) > 1
  rn <- function(d) if (multi) d$series else NULL
  drop_series <- function(d) d[, setdiff(names(d), "series"), drop = FALSE]
  tsx_cat_block(
    title = "Augmented Dickey-Fuller Tests (NO CONSTANT, NO TREND)",
    notes = c("T-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
              "P values are approximate based on tables"),
    table = tsx_format_table(drop_series(x$none), c(0, digits, digits, digits),
                             row_names = rn(x$none),
                             col_names = c("Lags", "z(t-1)", "T-Test", "P-value")))
  cat("\n")
  tsx_cat_block(
    title = "Augmented Dickey-Fuller Tests (CONSTANT, NO TREND)",
    notes = c("T-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
              "F-Test (Phi1) is for H0: Rho= 1 and Ct= 0"),
    table = tsx_format_table(drop_series(x$const), c(0, rep(digits, 7)),
                             row_names = rn(x$const),
                             col_names = c("Lags", "z(t-1)", "T-Test", "P-value", "Ct",
                                           "T-Test", "F-Test", "P-value")))
  cat("\n")
  tsx_cat_block(
    title = "Augmented Dickey-Fuller Tests (CONSTANT AND TREND)",
    notes = c("T-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
              "F-Test (Phi3) is for H0: Rho= 1 and D= 0"),
    table = tsx_format_table(drop_series(x$trend), c(0, rep(digits, 9)),
                             row_names = rn(x$trend),
                             col_names = c("Lags", "z(t-1)", "T-Test", "P-value", "Ct",
                                           "T-Test", "D", "T-Test", "F-Test", "P-value")))
  invisible(x)
}
