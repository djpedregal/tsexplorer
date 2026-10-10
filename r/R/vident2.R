#' Multivariate sample autocorrelation functions
#'
#' Sample autocorrelation matrices and partial lag autocorrelation matrices
#' (Heyse and Wei, 1985) or partial autoregression matrices (Tiao and Box,
#' 1981) of a vector of time series, together with the information criteria,
#' the likelihood ratio statistic of adding one lag to a VAR model and a
#' multivariate portmanteau test.
#'
#' @param y Time series data (see [as_tsx_matrix()]), at least two series.
#' @param ncoef Number of lags. Default `min(38, ceiling(T / 4 / m * 2))`.
#' @param s Seasonal period (only for plots).
#' @param npar Number of estimated parameters (if `y` are residuals); the
#'   degrees of freedom of the portmanteau test are `m^2 (lag - npar)`.
#' @param type `0` for partial lag autocorrelation matrices, `1` for partial
#'   autoregression matrices.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vident2` with fields
#'   * `call`, `series`,
#'   * `acf`, `se_acf`, `pacf`, `se_pacf`: arrays `m x m x (ncoef + 1)` for
#'     lags `0:ncoef`. Element `[a, b, k + 1]` is the correlation between
#'     series `a` at time `t` and series `b` at time `t - k`. At lag 0 the
#'     partial matrices repeat the correlation matrix,
#'   * `stats`: data.frame with columns `lag`, `aic`, `sbc`, `chi`, `p_chi`
#'     (likelihood ratio test of a VAR(lag) against a VAR(lag - 1)),
#'     `p_q` (multivariate portmanteau test of Hosking (1980) with the
#'     correction of Li and McLeod (1981),
#'     \eqn{T \sum_k tr(R_k' R_0^{-1} R_k R_0^{-1}) + m^2 k (k + 1) / (2T)})
#'     and `det_sigma`.
#' @references
#' Tiao, G.C. and Box, G.E.P. (1981). Modeling multiple time series with
#' applications. *Journal of the American Statistical Association*, 76,
#' 802-816.
#'
#' Heyse, J.F. and Wei, W.W.S. (1985). The partial lag autocorrelation
#' function. Technical Report 32, Temple University.
#'
#' Hosking, J.R.M. (1980). The multivariate portmanteau statistic. *Journal
#' of the American Statistical Association*, 75, 602-608.
#'
#' Li, W.K. and McLeod, A.I. (1981). Distribution of the residual
#' autocorrelations in multivariate ARMA time series models. *Journal of the
#' Royal Statistical Society B*, 43, 231-239.
#' @examples
#' r <- vident2(vdif(log(lydia_pinkham)), ncoef = 8)
#' r
#' plot(r, series = c(1, 2))
#' @export
vident2 <- function(y, ncoef = NULL, s = 12, npar = 0, type = 0, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  if (m < 2) stop("'vident2' needs at least two series.", call. = FALSE)
  if (is.null(ncoef)) ncoef <- min(38, ceiling(n / 4 / m * 2))
  ncoef <- min(tsx_check_int(ncoef, "ncoef"), n - 5, n - 3)
  miss <- anyNA(y)
  zs <- tsx_standardize(y)
  z <- sweep(y, 2, colMeans(y, na.rm = TRUE), "-")
  det_sa <- det(crossprod(z) / n)
  acf <- array(0, c(m, m, ncoef + 1))
  pacf <- array(NA_real_, c(m, m, ncoef + 1))
  se_acf <- array(0, c(m, m, ncoef + 1))
  se_pacf <- array(NA_real_, c(m, m, ncoef + 1))
  r0 <- tsx_nancov(zs)
  r0i <- solve(r0)
  acf[, , 1] <- r0
  pacf[, , 1] <- r0
  se_acf[, , 1] <- 1 / sqrt(n)
  se_pacf[, , 1] <- 1 / sqrt(n)
  ss <- sqrt(colSums(z^2))
  for (k in seq_len(ncoef)) {
    if (miss) {
      p <- tsx_nanprod(t(zs[(k + 1):n, , drop = FALSE]), zs[1:(n - k), , drop = FALSE])
      acf[, , k + 1] <- p$prod / p$n
    } else {
      acf[, , k + 1] <- crossprod(z[(k + 1):n, , drop = FALSE], z[1:(n - k), , drop = FALSE]) /
        outer(ss, ss)
    }
    se_acf[, , k + 1] <- 1 / sqrt(n - k)
  }
  if (type == 0) {
    se_pacf[, , -1] <- 1 / sqrt(n)
    pacf[, , 2] <- acf[, , 2]
  }
  st <- data.frame(lag = seq_len(ncoef), aic = NA_real_, sbc = NA_real_, chi = NA_real_,
                   p_chi = NA_real_, p_q = NA_real_, det_sigma = NA_real_)
  cumtr <- 0
  for (i in seq_len(ncoef)) {
    v <- tsx_mvar(z, seq_len(i), const = TRUE)
    if (type == 1) {
      idx <- ((i - 1) * m + 1):(i * m)
      pacf[, , i + 1] <- t(v$p[idx, , drop = FALSE])
      se_pacf[, , i + 1] <- t(v$se_p[idx, , drop = FALSE])
    } else if (i < ncoef) {
      vb <- tsx_mvar(z, seq_len(i), const = TRUE, partial = TRUE)
      u <- v$e[(nrow(v$e) - nrow(vb$e) + 1):nrow(v$e), , drop = FALSE]
      cr <- tsx_nancorr(cbind(u, vb$e))
      pacf[, , i + 2] <- cr[1:m, (m + 1):(2 * m)]
    }
    det_s <- det(v$sigma)
    st$aic[i] <- v$aic
    st$sbc[i] <- v$sbc
    st$chi[i] <- -(n - i - 1 - 0.5 - m * i) * log(det_s / det_sa)
    st$det_sigma[i] <- det_s
    det_sa <- det_s
    rk <- acf[, , i + 1]
    cumtr <- cumtr + sum(diag(t(rk) %*% r0i %*% rk %*% r0i))
    q <- n * cumtr + m * m * i * (i + 1) / 2 / n
    if (i > npar) st$p_q[i] <- stats::pchisq(q, m * m * (i - npar), lower.tail = FALSE)
  }
  st$p_chi <- stats::pchisq(st$chi, m * m, lower.tail = FALSE)
  dn <- list(colnames(y), colnames(y), paste0("lag", 0:ncoef))
  dimnames(acf) <- dimnames(pacf) <- dimnames(se_acf) <- dimnames(se_pacf) <- dn
  tsx_result("vident2", call = list(ncoef = ncoef, s = s, npar = npar, type = type),
             series = colnames(y), acf = acf, se_acf = se_acf, pacf = pacf,
             se_pacf = se_pacf, stats = st)
}

#' @export
print.tsx_vident2 <- function(x, digits = NULL, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  m <- length(x$series)
  if (is.null(digits)) digits <- max(2, 7 - m)
  lab <- if (x$call$type == 1) "Partial Autoregression" else "Partial Lag Autocorrelation"
  cat(strrep("-", 60), "\n", "Multivariate Sample Autocorrelation and ", lab, " Functions\n",
      strrep("-", 60), "\n", sep = "")
  fmt <- function(v) formatC(v, format = "f", digits = digits, width = digits + 4)
  for (k in 0:x$call$ncoef) {
    if (k > 0) {
      s <- x$stats[k, ]
      cat(sprintf("k=%d AIC=%.4f SBC=%.4f Chi=%.4f P-Chi=%.4f P-QTest=%.4f |Sigma|=%.4g\n",
                  k, s$aic, s$sbc, s$chi, s$p_chi, s$p_q, s$det_sigma))
    } else {
      cat("k= 0\n")
    }
    a <- x$acf[, , k + 1]
    p <- x$pacf[, , k + 1]
    ma <- matrix(tsx_signif_marks(a / x$se_acf[, , k + 1]), m)
    mp <- if (k == 0) matrix(".", m, m) else {
      rp <- p / x$se_pacf[, , k + 1]
      rp[is.na(rp)] <- 0
      matrix(tsx_signif_marks(rp), m)
    }
    for (i in seq_len(m)) {
      cat(paste(ma[i, ], collapse = ""), " | ", paste(mp[i, ], collapse = ""), " | ",
          paste(fmt(a[i, ]), collapse = " "),
          if (k > 0) paste0(" | ", paste(fmt(p[i, ]), collapse = " ")), "\n", sep = "")
    }
    cat("\n")
  }
  invisible(x)
}

#' @param x An object of class `tsx_vident2`.
#' @param series For the plot, one series (index or name) to plot its ACF and
#'   partial function, or two series to plot their cross correlations.
#' @param ... Not used.
#' @rdname vident2
#' @export
plot.tsx_vident2 <- function(x, series = 1, ...) {
  m <- length(x$series)
  idx <- vapply(series, function(s) {
    if (is.character(s)) match(s, x$series) else as.integer(s)
  }, integer(1))
  if (anyNA(idx) || any(idx < 1 | idx > m)) stop("Invalid 'series'.", call. = FALSE)
  i <- idx[1]
  j <- if (length(idx) > 1) idx[2] else i
  nc <- x$call$ncoef
  lab <- if (x$call$type == 1) "Partial Autoregression" else "Partial Lag Autocorrelation"
  if (i == j) {
    lags <- seq_len(nc)
    v <- cbind(x$acf[i, i, -1], x$pacf[i, i, -1])
    se <- cbind(x$se_acf[i, i, -1], x$se_pacf[i, i, -1])
    titles <- c(paste0("Series ", x$series[i], ": Multivariate Sample Autocorrelation Function"),
                paste0("Series ", x$series[i], ": Multivariate Sample ", lab, " Function"))
  } else {
    lags <- -nc:nc
    side <- function(arr, a, b) c(rev(arr[a, b, -1]), arr[a, b, 1], arr[b, a, -1])
    v <- cbind(side(x$acf, i, j), side(x$pacf, i, j))
    se <- cbind(side(x$se_acf, i, j), side(x$se_pacf, i, j))
    ni <- x$series[i]
    nj <- x$series[j]
    titles <- c(paste0("CCF between ", ni, "(t) and ", nj, "(t-k) [k < 0] and ",
                       ni, "(t-k) and ", nj, "(t) [k > 0]"),
                paste0("PCCF between ", ni, "(t) and ", nj, "(t-k) [k < 0] and ",
                       ni, "(t-k) and ", nj, "(t) [k > 0]"))
  }
  tsx_plot_correlogram(lags, v, se, x$call$s, titles)
  invisible(x)
}
