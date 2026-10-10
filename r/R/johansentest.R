#' Johansen cointegration tests
#'
#' Maximum eigenvalue and trace statistics of Johansen (1988) for the number
#' of cointegrating relations of a VAR model in levels with `lag` lags,
#' under three specifications of the deterministic terms (none, constant,
#' constant and linear trend). For one series the test is a unit root test.
#'
#' P-values are approximate, interpolated (and linearly extrapolated, clamped
#' to `[0, 1]`) in tables of critical values for up to 5 non-stationary
#' directions; beyond that they are `NA`. The model without deterministic
#' terms uses the tables of Osterwald-Lenum (1992, Table 0) and the model with
#' an unrestricted constant those of Johansen and Juselius (1990, Table A1).
#' There are no tables for the model with an unrestricted linear trend, whose
#' p-values are `NA`.
#'
#' @inheritParams adftest
#' @param lags Lag order(s) of the VAR in levels (the VECM includes
#'   `lag - 1` lagged differences). Default: `2:min(floor(sqrt(T)), 20)` for
#'   one series (lag 1 is removed) and `min(floor(sqrt(T)), 20)` for several.
#' @return An object of class `tsx_johansentest` with fields `call`, `series`
#'   and
#'   * `table`: data.frame with columns `lag`, `type` (`"max"` or `"trace"`),
#'     `h0`, `h1` (number of cointegrating relations under the null and the
#'     alternative), `stat_none`, `p_none`, `stat_const`, `p_const`,
#'     `stat_trend`, `p_trend`,
#'   * `eigen`: data.frame with columns `lag`, `i`, `eigen_none`, `lr_none`,
#'     `eigen_const`, `lr_const`, `eigen_trend`, `lr_trend` (eigenvalues and
#'     \eqn{-T \log(1 - \lambda_i)}).
#' @references
#' Johansen, S. (1988). Statistical analysis of cointegration vectors.
#' *Journal of Economic Dynamics and Control*, 12, 231-254.
#'
#' Johansen, S. and Juselius, K. (1990). Maximum likelihood estimation and
#' inference on cointegration. *Oxford Bulletin of Economics and Statistics*,
#' 52, 169-210.
#'
#' Osterwald-Lenum, M. (1992). A note with quantiles of the asymptotic
#' distribution of the maximum likelihood cointegration rank test statistics.
#' *Oxford Bulletin of Economics and Statistics*, 54, 461-472.
#' @examples
#' johansentest(log(lydia_pinkham))
#' @export
johansentest <- function(y, lags = NULL, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  lags <- tsx_unitroot_lags(lags, n, m)
  if (m == 1) lags <- lags[lags != 1]
  if (length(lags) == 0) stop("'lags' must include values greater than 1 for one series.",
                              call. = FALSE)
  h0 <- rep(0:(m - 1), each = 2)[seq_len(2 * m - 1)]
  h1 <- as.vector(rbind(1:m, m))[seq_len(2 * m - 1)]
  type <- rep(c("max", "trace"), m)[seq_len(2 * m - 1)]
  tab <- NULL
  eig <- NULL
  for (L in lags) {
    res <- lapply(c("none", "const", "trend"), function(det) tsx_johansen_eigen(y, L, det))
    stat <- lapply(res, function(r) {
      cum <- rev(cumsum(rev(r$lr)))
      as.vector(rbind(r$lr, cum))[seq_len(2 * m - 1)]
    })
    tl <- data.frame(lag = L, type = type, h0 = h0, h1 = h1,
                     stat_none = stat[[1]], stat_const = stat[[2]],
                     stat_trend = stat[[3]], stringsAsFactors = FALSE)
    # Critical value tables: dist = 1 is Osterwald-Lenum (1992) Table 0 (no
    # deterministic terms), dist = 3 is Johansen-Juselius (1990) Table A1
    # (unrestricted constant). No table for the unrestricted trend model.
    tl$p_none <- tsx_johansen_p(tl$stat_none, m - h0, type, 1)
    tl$p_const <- tsx_johansen_p(tl$stat_const, m - h0, type, 3)
    tl$p_trend <- NA_real_
    tab <- rbind(tab, tl[, c("lag", "type", "h0", "h1", "stat_none", "p_none",
                             "stat_const", "p_const", "stat_trend", "p_trend")])
    eig <- rbind(eig, data.frame(lag = L, i = seq_len(m),
                                 eigen_none = res[[1]]$lambda, lr_none = res[[1]]$lr,
                                 eigen_const = res[[2]]$lambda, lr_const = res[[2]]$lr,
                                 eigen_trend = res[[3]]$lambda, lr_trend = res[[3]]$lr))
  }
  tsx_result("johansentest", call = list(lags = lags), series = colnames(y),
             table = tab, eigen = eig)
}

# Eigenvalues of the reduced rank regression (Johansen 1988).
# det: "none", "const" or "trend".
tsx_johansen_eigen <- function(y, L, det) {
  n <- nrow(y)
  m <- ncol(y)
  dz <- diff(y)
  if (L > 1) {
    lagy <- tsx_delay(dz, 0:(L - 1))
  } else {
    lagy <- dz
  }
  tz <- nrow(lagy)
  x <- lagy[, -(1:m), drop = FALSE]
  if (det %in% c("const", "trend")) x <- cbind(x, 1)
  if (det == "trend") x <- cbind(x, seq_len(tz))
  dzt <- lagy[, 1:m, drop = FALSE]
  zlag <- y[(n - tz):(n - 1), , drop = FALSE]
  if (ncol(x) > 0) {
    ixx <- solve(tsx_nanprod(t(x), x)$prod)
    u <- dzt - tsx_nanprod(x, ixx %*% tsx_nanprod(t(x), dzt)$prod)$prod
    v <- zlag - tsx_nanprod(x, ixx %*% tsx_nanprod(t(x), zlag)$prod)$prod
  } else {
    u <- dzt
    v <- zlag
  }
  uu <- tsx_nanprod(t(u), u)$prod / tz
  vv <- tsx_nanprod(t(v), v)$prod / tz
  uv <- tsx_nanprod(t(u), v)$prod / tz
  lambda <- Re(eigen(solve(vv) %*% t(uv) %*% solve(uu) %*% uv, only.values = TRUE)$values)
  lambda <- sort(lambda, decreasing = TRUE)
  list(lambda = lambda, lr = -n * log(1 - lambda))
}

# Approximate p-values of the Johansen statistics.
# g: number of non-stationary directions (m - h0); type "max" or "trace";
# dist: 1, 2 or 3 (tables of the three deterministic specifications).
tsx_johansen_p <- function(x, g, type, dist) {
  vapply(seq_along(x), function(i) {
    if (g[i] > 5 || is.na(x[i])) return(NA_real_)
    tab <- tsx_tables$joh[[paste0(type[i], "_", dist)]]
    tsx_interpol(tab[g[i], ], tsx_tables$joh_p, x[i], c(0, 1))
  }, numeric(1))
}

#' @export
print.tsx_johansentest <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  t <- x$table
  hh <- paste0("h= ", t$h0, "  -  h= ", t$h1)
  if (length(x$series) == 1) hh <- paste("Lags", t$lag)
  lines <- tsx_format_table(t[, c("stat_none", "p_none", "stat_const", "p_const",
                                  "stat_trend", "p_trend")], digits,
                            row_names = hh,
                            col_names = c("Stat1", "P-value", "Stat2", "P-value",
                                          "Stat3", "P-value"))
  tsx_cat_block(
    title = paste0("Johansen Cointegration Tests",
                   if (length(x$series) > 1) paste0(" (lags= ", paste(unique(t$lag), collapse = ", "), ")")),
    notes = c(if (length(x$series) > 1) "'h' is the number of cointegrated relations",
              "Stat1: test statistic based on model without deterministic parts",
              "Stat2: test statistic based on model including a constant term",
              "Stat3: test statistic based on model including a constant and linear trend",
              "Critical values are approximate based on tables",
              "(no tables available for Stat3: P-values are NA)"),
    table = lines)
  if (length(x$series) > 1) {
    cat("\n")
    e <- x$eigen
    tsx_cat_block(table = tsx_format_table(
      e[, -1], c(0, rep(digits, 6)),
      col_names = c("i", "Eigen1", "-T[1-l(i)]", "Eigen2", "-T[1-l(i)]", "Eigen3",
                    "-T[1-l(i)]")))
  }
  invisible(x)
}
