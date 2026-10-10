#' Phillips-Perron unit root tests
#'
#' Phillips-Perron \eqn{Z_t} statistics computed on the same three
#' regressions as [adftest()] (no deterministic terms, constant, constant and
#' trend, each one including `lag` lagged differences). The long run variance
#' of the residuals is estimated with a Bartlett (Newey-West) window with
#' `ncovs` autocovariances.
#'
#' @inheritParams adftest
#' @param ncovs Number of autocovariances of the residuals in the long run
#'   variance. Default `floor(4 * (T / 100)^0.25)`.
#' @return An object of class `tsx_vphillips` with fields `call`, `series`,
#'   `n` and the data.frames `none`, `const` and `trend` with columns
#'   `series`, `lag`, `rho`, `z_t` (Phillips-Perron statistic) and `p_value`.
#' @references
#' Phillips, P.C.B. and Perron, P. (1988). Testing for a unit root in time
#' series regression. *Biometrika*, 75, 335-346.
#'
#' Newey, W.K. and West, K.D. (1987). A simple, positive semi-definite,
#' heteroskedasticity and autocorrelation consistent covariance matrix.
#' *Econometrica*, 55, 703-708.
#' @examples
#' vphillips(log(airpas), lags = 1:3)
#' @export
vphillips <- function(y, lags = NULL, ncovs = NULL, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  lags <- tsx_unitroot_lags(lags, n, m)
  if (is.null(ncovs)) ncovs <- floor(4 * (n / 100)^0.25)
  ncovs <- tsx_check_int(ncovs, "ncovs", 0)
  out <- list(none = NULL, const = NULL, trend = NULL)
  cols <- list(none = c(1), const = c(1, 2), trend = c(1, 2, 3))
  for (i in seq_len(m)) {
    for (p in lags) {
      d <- tsx_adf_design(y[, i], p)
      for (mod in names(cols)) {
        r <- tsx_adf_ols(d$y, d$x[, c(cols[[mod]], seq_len(p) + 3), drop = FALSE])
        tstat <- (r$beta[1] - 1) / r$se[1]
        z <- tsx_pp_correction(tstat, r$e, r$sse, r$s2, r$se[1], n, ncovs)
        out[[mod]] <- rbind(out[[mod]], data.frame(series = colnames(y)[i], lag = p,
                                                   rho = r$beta[1], z_t = z))
      }
    }
  }
  tabs <- c(none = "t_none", const = "t_const", trend = "t_trend")
  for (mod in names(out)) {
    out[[mod]]$p_value <- adfcritical(out[[mod]]$z_t, n, tabs[[mod]])
    rownames(out[[mod]]) <- NULL
  }
  tsx_result("vphillips", call = list(lags = lags, ncovs = ncovs),
             series = colnames(y), n = n,
             none = out$none, const = out$const, trend = out$trend)
}

# Phillips-Perron correction of the t statistic.
# nw: long run variance (Bartlett window); g0: residual variance (both
# divided by the full sample size T).
tsx_pp_correction <- function(tstat, e, sse, s2, se_rho, n, ncovs) {
  nw <- sse
  ne <- length(e)
  for (k in seq_len(ncovs)) {
    if (k >= ne) break
    nw <- nw + 2 * (1 - k / (ncovs + 1)) * sum(e[1:(ne - k)] * e[(k + 1):ne])
  }
  nw <- nw / n
  g0 <- sse / n
  sqrt(g0 / nw) * tstat - 0.5 * (nw - g0) / sqrt(nw) * n * se_rho / sqrt(s2)
}

#' @export
print.tsx_vphillips <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  multi <- length(x$series) > 1
  titles <- c(none = "Phillips-Perron Tests (NO CONSTANT, NO TREND)",
              const = "Phillips-Perron Tests (CONSTANT, NO TREND)",
              trend = "Phillips-Perron Tests (CONSTANT AND TREND)")
  for (mod in names(titles)) {
    d <- x[[mod]]
    tsx_cat_block(
      title = titles[[mod]],
      notes = if (mod == "none") c(paste("Number of residual covs=", x$call$ncovs),
                                   "PP-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
                                   "P values are approximate based on tables"),
      table = tsx_format_table(d[, -1], c(0, digits, digits, digits),
                               row_names = if (multi) d$series,
                               col_names = c("Lags", "z(t-1)", "PP-Test", "P-value")))
    cat("\n")
  }
  invisible(x)
}
