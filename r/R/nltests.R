#' Non-linearity tests based on squares
#'
#' McLeod-Li (portmanteau on the ACF of the squared series), Monti (on the
#' PACF of the squares) and Pena-Rodriguez (determinant of the autocorrelation
#' matrix of the squares) tests.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param ncoef Number of lags. Default `min(38, ceiling(T / 4 / m * 2))`.
#' @param series Series to analyse (index or name).
#' @param names Optional names of the series.
#' @return An object of class `tsx_nltests` with fields `call`, `series` and
#'   `table`, a data.frame with columns `lag`, `acf`, `se_acf`, `q_mll`,
#'   `p_mll`, `pacf`, `se_pacf`, `q_mt`, `p_mt`, `d_pr`, `p_pr` (statistics
#'   and p-values of the three tests for each lag).
#' @references
#' McLeod, A.I. and Li, W.K. (1983). Diagnostic checking ARMA time series
#' models using squared-residual autocorrelations. *Journal of Time Series
#' Analysis*, 4, 269-273.
#'
#' Monti, A.C. (1994). A proposal for a residual autocorrelation test in
#' linear models. *Biometrika*, 81, 776-780.
#'
#' Pena, D. and Rodriguez, J. (2002). A powerful portmanteau test of lack of
#' fit for time series. *Journal of the American Statistical Association*,
#' 97, 601-610.
#' @examples
#' nltests(vdif(log(airpas), c(1, 1), c(1, 12)), ncoef = 12)
#' @export
nltests <- function(y, ncoef = NULL, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  if (is.null(ncoef)) ncoef <- min(38, ceiling(n / 4 / m * 2))
  ncoef <- min(tsx_check_int(ncoef, "ncoef"), n - 5)
  i <- tsx_series_index(series, y)[1]
  r <- tsx_acf_pacf(y[, i]^2, ncoef, 0)
  lags <- seq_len(ncoef)
  rk <- sqrt((n + 2) / (n - lags)) * r$sacf
  d <- numeric(ncoef)
  for (k in lags) {
    rm <- stats::toeplitz(c(1, rk[seq_len(k)]))
    d[k] <- -(n / (k + 1)) * log(abs(det(rm)))
  }
  pd <- stats::pgamma(d, shape = 3 * lags * (lags + 1) / (8 * lags + 4),
                      scale = 3 * lags / (4 * lags + 2), lower.tail = FALSE)
  tab <- data.frame(lag = lags, acf = r$sacf, se_acf = r$se_acf, q_mll = r$q,
                    p_mll = r$p_q, pacf = r$spacf, se_pacf = r$se_pacf, q_mt = r$q_mt,
                    p_mt = r$p_q_mt, d_pr = d, p_pr = pd)
  tsx_result("nltests", call = list(ncoef = ncoef, series = i), series = colnames(y)[i],
             table = tab)
}

#' @export
print.tsx_nltests <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  t <- x$table
  lines <- tsx_format_table(
    data.frame(t$lag, t$acf, tsx_signif_marks(t$acf / t$se_acf), t$q_mll, t$p_mll,
               t$pacf, tsx_signif_marks(t$pacf / t$se_pacf), t$q_mt, t$p_mt, t$d_pr, t$p_pr),
    c(0, digits, 0, digits, digits, digits, 0, digits, digits, digits, digits),
    col_names = c("Lag", "SACF", "", "MLL", "P-value", "SPACF", "", "MT", "P-value", "PR",
                  "P-value"))
  tsx_cat_block(title = "Non-Linearity Tests",
                notes = c("MLL: McLeod & Li (1983) Test", "MT:  Monti (1994) Test",
                          paste0("PR:  Pe", intToUtf8(241L), "a & Rodriguez (2002) Test"), "H0:  Process is Linear",
                          paste("Series", x$series)),
                table = lines)
  invisible(x)
}

#' @export
plot.tsx_nltests <- function(x, ...) {
  t <- x$table
  tsx_plot_correlogram(t$lag, cbind(t$acf, t$pacf), cbind(t$se_acf, t$se_pacf),
                       max(t$lag) + 2,
                       c(paste0("Series ", x$series, ": Sample Autocorrelation Function of Squared Data"),
                         paste0("Series ", x$series, ": Sample Partial Autocorrelation Function of Squared Data")))
  invisible(x)
}

#' Tsay (1986) non-linearity test
#'
#' Tsay (1986) F test: the residuals \eqn{e_t} of an AR(`lags`) model with
#' constant are regressed on the cross products \eqn{z_{t-i} z_{t-j}}
#' (\eqn{i \le j}), previously orthogonalised with respect to the constant
#' and the lags. With \eqn{k = p(p+1)/2} products and \eqn{n} observations,
#' \deqn{F = \frac{(\sum e_t^2 - \sum \varepsilon_t^2) / k}
#'              {\sum \varepsilon_t^2 / (n - p - k - 1)}}
#' follows an \eqn{F(k, n - p - k - 1)} distribution under linearity.
#' Missing values remove the corresponding rows.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param lags Order of the AR model (at least 2). Default 4.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vtsay` with fields `call`, `series`,
#'   `table` (data.frame with columns `series`, `f`, `df1`, `df2`, `p_value`)
#'   and `regressions` (data.frame with the auxiliary regression of the AR
#'   residuals on the orthogonalised products: `series`, `variable`, `beta`,
#'   `t`, `p_value`, two sided).
#' @references
#' Tsay, R.S. (1986). Nonlinearity tests for time series. *Biometrika*, 73,
#' 461-466.
#' @examples
#' vtsay(vdif(log(airpas), c(1, 1), c(1, 12)))
#' @export
vtsay <- function(y, lags = 4, names = NULL) {
  y <- as_tsx_matrix(y, names)
  m <- ncol(y)
  lags <- max(2, max(as.integer(round(lags))))
  labs <- NULL
  for (i in seq_len(lags)) for (j in i:lags) labs <- c(labs, paste0("z(t-", i, ")*z(t-", j, ")"))
  kk <- lags * (lags + 1) / 2
  tab <- data.frame(series = colnames(y), f = NA_real_, df1 = kk, df2 = NA_real_,
                    p_value = NA_real_, stringsAsFactors = FALSE)
  regs <- NULL
  for (s in seq_len(m)) {
    x <- tsx_delay(y[, s], 0:lags)
    x <- x[stats::complete.cases(x), , drop = FALSE]
    n <- nrow(x)
    xl <- cbind(1, x[, -1, drop = FALSE])
    e <- tsx_ols(x[, 1], xl)$e
    xx <- NULL
    for (i in seq_len(lags)) {
      for (j in i:lags) xx <- cbind(xx, tsx_ols(xl[, i + 1] * xl[, j + 1], xl)$e)
    }
    r <- tsx_ols(e, xx)
    df2 <- n - lags - kk - 1
    if (df2 < 1) stop("Too few observations for the Tsay test with ", lags, " lags.",
                      call. = FALSE)
    s2 <- r$sse / df2
    f <- ((sum(e^2) - r$sse) / kk) / s2
    t <- as.vector(r$beta) / sqrt(diag(s2 * r$ixx))
    tab$f[s] <- f
    tab$df2[s] <- df2
    tab$p_value[s] <- stats::pf(f, kk, df2, lower.tail = FALSE)
    regs <- rbind(regs, data.frame(series = colnames(y)[s], variable = labs,
                                   beta = as.vector(r$beta), t = t,
                                   p_value = 2 * stats::pt(-abs(t), df2),
                                   stringsAsFactors = FALSE))
  }
  tsx_result("vtsay", call = list(lags = lags), series = colnames(y), table = tab,
             regressions = regs)
}

#' @export
print.tsx_vtsay <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = c("Tsay(1986) Non-Linear Test", "H0: Process is linear"),
                notes = paste0("Summary table based on an AR(", x$call$lags, ") Model:"),
                table = tsx_format_table(x$table[, -1], c(digits, 0, 0, digits),
                                         row_names = x$series,
                                         col_names = c("Tsay-F", "DoF1", "DoF2", "P-value")))
  cat("\nAuxiliary Regressions:\n")
  for (s in x$series) {
    r <- x$regressions[x$regressions$series == s, ]
    tsx_cat_block(title = paste("Series:", s),
                  table = tsx_format_table(r[, c("beta", "t", "p_value")], digits,
                                           row_names = r$variable,
                                           col_names = c("Betas", "T", "P-value")))
  }
  invisible(x)
}
