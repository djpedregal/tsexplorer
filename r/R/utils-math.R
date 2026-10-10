# Internal numerical helpers.

# Matrix of lagged variables.
# Rows are t = maxlag+1, ..., T; block i holds y lagged lags[i] periods.
tsx_delay <- function(y, lags) {
  y <- as.matrix(y)
  n <- nrow(y)
  m <- ncol(y)
  maxlag <- max(lags)
  out <- matrix(0, n - maxlag, m * length(lags))
  for (i in seq_along(lags)) {
    out[, ((i - 1) * m + 1):(i * m)] <-
      y[(maxlag - lags[i] + 1):(n - lags[i]), , drop = FALSE]
  }
  out
}

#' Differencing of a vector of time series
#'
#' Applies multiplicative difference operators
#' \eqn{\prod_j (1 - B^{s_j})^{d_j}} to each series.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param order Difference orders. A vector applies the same multiplicative
#'   polynomials to every series; a matrix with one row per series allows
#'   different orders for each series (the last row is recycled).
#' @param s Seasonal period of each polynomial (same layout as `order`).
#' @return Matrix of differenced data. The first `r` observations are lost,
#'   being `r` the largest total order of differencing among the series.
#' @examples
#' y <- log(airpas)
#' head(vdif(y, c(1, 1), c(1, 12)))
#' head(vdif(cbind(y, y), rbind(c(1, 0), c(1, 1)), c(1, 12)))
#' @export
vdif <- function(y, order = 1, s = 1) {
  y <- as_tsx_matrix(y, trim = FALSE)
  n <- nrow(y)
  m <- ncol(y)
  order <- tsx_rows_as_series(order, m)
  s <- tsx_rows_as_series(s, m)
  if (ncol(s) < ncol(order)) s <- cbind(s, matrix(1, m, ncol(order) - ncol(s)))
  polys <- vector("list", m)
  la <- 0
  for (i in seq_len(m)) {
    a <- 1
    for (j in seq_len(ncol(order))) {
      for (k in seq_len(order[i, j])) {
        if (s[i, j] > 0) a <- tsx_conv(a, c(1, rep(0, s[i, j] - 1), -1))
      }
    }
    polys[[i]] <- a
    la <- max(la, length(a))
  }
  if (la > n) stop("Not enough data for the required differences.", call. = FALSE)
  out <- matrix(NA_real_, n - la + 1, m)
  rows <- la:n
  for (i in seq_len(m)) {
    a <- polys[[i]]
    acc <- 0
    for (k in seq_along(a)) acc <- acc + a[k] * y[rows - k + 1, i]
    out[, i] <- acc
  }
  colnames(out) <- colnames(y)
  out
}

# Expand a vector/matrix of per-series options to m rows (last row recycled).
tsx_rows_as_series <- function(x, m) {
  x <- if (is.null(dim(x))) matrix(x, nrow = 1) else as.matrix(x)
  if (nrow(x) < m) x <- rbind(x, x[rep(nrow(x), m - nrow(x)), , drop = FALSE])
  x[seq_len(m), , drop = FALSE]
}

# Polynomial multiplication.
tsx_conv <- function(a, b) {
  out <- rep(0, length(a) + length(b) - 1)
  for (i in seq_along(a)) {
    idx <- i:(i + length(b) - 1)
    out[idx] <- out[idx] + a[i] * b
  }
  out
}

# Standardisation of each column (mean 0, standard deviation 1,
# with standard deviation computed with T - 1). Zero standard deviations are
# replaced by one.
tsx_standardize <- function(y) {
  y <- as.matrix(y)
  mz <- colMeans(y, na.rm = TRUE)
  sz <- apply(y, 2, stats::sd, na.rm = TRUE)
  sz[!is.na(sz) & sz == 0] <- 1
  sweep(sweep(y, 2, mz, "-"), 2, sz, "/")
}

# Matrix product ignoring missing products. Returns the product
# and the number of non missing terms of each element.
tsx_nanprod <- function(a, b) {
  a <- as.matrix(a)
  b <- as.matrix(b)
  a0 <- a
  b0 <- b
  a0[is.na(a0)] <- 0
  b0[is.na(b0)] <- 0
  list(prod = a0 %*% b0, n = (!is.na(a)) %*% (!is.na(b)))
}

# Covariance matrix with pairwise deletion of missing values.
tsx_nancov <- function(y) {
  y <- as.matrix(y)
  y <- sweep(y, 2, colMeans(y, na.rm = TRUE), "-")
  p <- tsx_nanprod(t(y), y)
  p$prod / (p$n - 1)
}

# Correlation matrix with pairwise deletion of missing values.
tsx_nancorr <- function(y) tsx_nancov(tsx_standardize(y))

#' Median absolute deviation with respect to the median
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @return Numeric vector with the MEDA of each series (missing values are
#'   ignored).
#' @examples
#' meda(airpas)
#' @export
meda <- function(y) {
  y <- as_tsx_matrix(y, trim = FALSE)
  apply(y, 2, function(x) stats::median(abs(x - stats::median(x, na.rm = TRUE)),
                                        na.rm = TRUE))
}

# Percentiles (equivalent to
# quantile(type = 5) inside the range of the data, clamped outside).
tsx_prctile <- function(y, p) {
  y <- as.matrix(y)
  out <- matrix(NA_real_, length(p), ncol(y))
  for (i in seq_len(ncol(y))) {
    zi <- sort(y[!is.na(y[, i]), i])
    n <- length(zi)
    if (n == 0) next
    x <- c(0, 100 * (seq_len(n) - 0.5) / n, 100)
    out[, i] <- stats::approx(x, c(zi[1], zi, zi[n]), p)$y
  }
  out
}

# Linear interpolation in the grid (x, y); linear extrapolation
# from the two extreme points outside the grid; result clamped to 'limits'.
tsx_interpol <- function(x, y, xi, limits = NULL) {
  if (is.na(xi) || anyNA(x)) return(NA_real_)
  keep <- c(which(diff(x) != 0), length(x))
  x <- x[keep]
  y <- y[keep]
  n <- length(x)
  if (xi < x[1]) {
    b <- solve(cbind(1, x[1:2]), y[1:2])
    yi <- b[1] + b[2] * xi
  } else if (xi > x[n]) {
    b <- solve(cbind(1, x[(n - 1):n]), y[(n - 1):n])
    yi <- b[1] + b[2] * xi
  } else {
    yi <- stats::approx(x, y, xi)$y
  }
  if (!is.null(limits)) yi <- min(max(yi, limits[1]), limits[2])
  unname(yi)
}

# Skewness and kurtosis (biased versions, divisor T).
tsx_skewness <- function(x) {
  x <- x[!is.na(x)]
  d <- x - mean(x)
  mean(d^3) / mean(d^2)^1.5
}

tsx_kurtosis <- function(x) {
  x <- x[!is.na(x)]
  d <- x - mean(x)
  mean(d^4) / mean(d^2)^2
}

# Ordinary least squares returning what the tests of the package need.
tsx_ols <- function(y, x) {
  ixx <- solve(crossprod(x))
  beta <- ixx %*% crossprod(x, y)
  e <- y - x %*% beta
  list(beta = beta, ixx = ixx, e = e, sse = sum(e^2))
}

# Least squares estimation of a VAR model with lags 'order'.
# const: include a constant; partial = TRUE regresses y(t - max(order) - 1)
# on the same regressors (used for partial lag autocorrelations).
# Missing values are handled with tsx_nanprod().
tsx_mvar <- function(y, order, const = TRUE, partial = FALSE) {
  y <- as.matrix(y)
  n <- nrow(y)
  m <- ncol(y)
  order <- as.vector(order)
  if (length(order) > 0 && order[1] == 0) order <- order[-1]
  if (length(order) == 0) return(NULL)
  lagy <- if (partial) tsx_delay(y, c(max(order) + 1, order)) else tsx_delay(y, c(0, order))
  x <- lagy[, -(1:m), drop = FALSE]
  if (const) x <- cbind(x, 1)
  yy <- lagy[, 1:m, drop = FALSE]
  if (anyNA(y)) {
    inv_xx <- solve(tsx_nanprod(t(x), x)$prod)
    p <- inv_xx %*% tsx_nanprod(t(x), yy)$prod
    e <- yy - tsx_nanprod(x, p)$prod
    s <- tsx_nanprod(t(e), e)$prod
  } else {
    inv_xx <- solve(crossprod(x))
    p <- qr.solve(x, yy)
    e <- yy - x %*% p
    s <- crossprod(e)
  }
  sigma <- s / n
  cov_p <- kronecker(sigma, inv_xx)
  se_p <- matrix(sqrt(diag(cov_p)), nrow(p), ncol(p))
  np <- (ncol(lagy) - m) / m
  k <- np * m * m + m
  aic <- (n * log(det(sigma)) + 2 * k) / n
  sbc <- (n * log(det(sigma)) + k * log(n)) / n
  list(p = p, se_p = se_p, sigma = sigma, aic = aic, sbc = sbc, e = e,
       cov_p = cov_p, inv_xx = inv_xx, lagy = lagy, x = x)
}

# Information criteria of a VAR(order) with constant.
tsx_auxvarsbc <- function(y, order) {
  y <- as.matrix(y)
  n <- nrow(y)
  m <- ncol(y)
  lagy <- if (order == 0) y else tsx_delay(y, 0:order)
  x <- cbind(lagy[, -(1:m), drop = FALSE], 1)
  yy <- lagy[, 1:m, drop = FALSE]
  if (anyNA(y)) {
    if (order == 0) {
      e <- y
    } else {
      b <- solve(tsx_nanprod(t(x), x)$prod) %*% tsx_nanprod(t(x), yy)$prod
      e <- yy - tsx_nanprod(x, b)$prod
    }
    s <- tsx_nanprod(t(e), e)$prod
  } else {
    e <- if (order == 0) y else yy - x %*% qr.solve(x, yy)
    s <- crossprod(e)
  }
  sigma <- s / n
  np <- (ncol(lagy) - m) / m
  ldet <- log(det(sigma))
  k <- np * m * m + m
  list(sigma = sigma,
       fpe = ldet + log((n + k) / (n - k)),
       aic = ldet + 2 * k / n,
       aicc = ldet + (2 * k + 2) / (n - k - 2),
       sbc = ldet + k * log(n) / n,
       hqc = ldet + 2 * k * log(log(n)) / n,
       e = e)
}

# Sample ACF, PACF, Ljung-Box and Monti tests of one series (common core of
# vident() and nltests()).
tsx_acf_pacf <- function(x, ncoef, npar = 0) {
  n <- length(x)
  zs <- as.vector(tsx_standardize(x))
  sacf <- numeric(ncoef)
  if (!anyNA(zs)) {
    den <- sum(zs^2)
    for (k in seq_len(ncoef)) sacf[k] <- sum(zs[1:(n - k)] * zs[(1 + k):n]) / den
  } else {
    for (k in seq_len(ncoef)) {
      pr <- zs[(k + 1):n] * zs[1:(n - k)]
      sacf[k] <- sum(pr, na.rm = TRUE) / sum(!is.na(pr))
    }
  }
  seacf <- numeric(ncoef)
  seacf[1] <- 1 / sqrt(n)
  if (ncoef > 1) seacf[2:ncoef] <- sqrt((1 + 2 * cumsum(sacf[1:(ncoef - 1)]^2)) / n)
  spacf <- tsx_durbin_levinson(sacf)
  sepacf <- rep(1 / sqrt(n), ncoef)
  lags <- seq_len(ncoef)
  df <- lags - npar
  q <- n * (n + 2) * cumsum(sacf^2 / (n - lags))
  qmt <- n * (n + 2) * cumsum(spacf^2 / (n - lags))
  pq <- ifelse(df > 0, stats::pchisq(q, pmax(df, 1), lower.tail = FALSE), NA_real_)
  pqmt <- ifelse(df > 0, stats::pchisq(qmt, pmax(df, 1), lower.tail = FALSE), NA_real_)
  list(sacf = sacf, spacf = spacf, se_acf = seacf, se_pacf = sepacf,
       q = q, p_q = pq, q_mt = qmt, p_q_mt = pqmt)
}

# Durbin-Levinson recursion: partial autocorrelations from autocorrelations.
tsx_durbin_levinson <- function(r) {
  nc <- length(r)
  spacf <- r
  fi <- numeric(nc)
  fi[1] <- r[1]
  if (nc > 1) {
    for (i in 1:(nc - 1)) {
      fi[i + 1] <- (r[i + 1] - sum(fi[1:i] * rev(r[1:i]))) / (1 - sum(fi * r))
      spacf[i + 1] <- fi[i + 1]
      fi[1:i] <- fi[1:i] - fi[i + 1] * rev(fi[1:i])
    }
  }
  spacf
}

# Marks '+' (> lim), '-' (< -lim), '.' otherwise and '@' for NA.
tsx_signif_marks <- function(x, lim = 2) {
  out <- ifelse(x > lim, "+", ifelse(x < -lim, "-", "."))
  out[is.na(x)] <- "@"
  out
}

# Nelder-Mead simplex (Lagarias et al., 1998): initial simplex with 5%
# perturbations (0.00025 for zero components), standard coefficients and
# stopping rules on tol_x and tol_fun.
tsx_fminsearch <- function(fun, x0, tol_x = 1e-4, tol_fun = 1e-4,
                           max_iter = 200 * length(x0),
                           max_fun_evals = 200 * length(x0), ...) {
  n <- length(x0)
  rho <- 1
  chi <- 2
  psi <- 0.5
  sigma <- 0.5
  v <- matrix(x0, n, n + 1)
  fv <- numeric(n + 1)
  fv[1] <- fun(x0, ...)
  for (j in seq_len(n)) {
    y <- x0
    y[j] <- if (y[j] != 0) 1.05 * y[j] else 0.00025
    v[, j + 1] <- y
    fv[j + 1] <- fun(y, ...)
  }
  ord <- order(fv)
  fv <- fv[ord]
  v <- v[, ord, drop = FALSE]
  iter <- 1
  nfev <- n + 1
  while (nfev < max_fun_evals && iter < max_iter) {
    if (max(abs(fv[1] - fv[-1])) <= max(tol_fun, 10 * .Machine$double.eps * fv[1]) &&
        max(abs(v[, -1, drop = FALSE] - v[, 1])) <= max(tol_x, 10 * .Machine$double.eps * max(v[, 1]))) {
      break
    }
    xbar <- rowMeans(v[, 1:n, drop = FALSE])
    xr <- (1 + rho) * xbar - rho * v[, n + 1]
    fxr <- fun(xr, ...)
    nfev <- nfev + 1
    shrink <- FALSE
    if (fxr < fv[1]) {
      xe <- (1 + rho * chi) * xbar - rho * chi * v[, n + 1]
      fxe <- fun(xe, ...)
      nfev <- nfev + 1
      if (fxe < fxr) {
        v[, n + 1] <- xe
        fv[n + 1] <- fxe
      } else {
        v[, n + 1] <- xr
        fv[n + 1] <- fxr
      }
    } else if (fxr < fv[n]) {
      v[, n + 1] <- xr
      fv[n + 1] <- fxr
    } else if (fxr < fv[n + 1]) {
      xc <- (1 + psi * rho) * xbar - psi * rho * v[, n + 1]
      fxc <- fun(xc, ...)
      nfev <- nfev + 1
      if (fxc <= fxr) {
        v[, n + 1] <- xc
        fv[n + 1] <- fxc
      } else {
        shrink <- TRUE
      }
    } else {
      xcc <- (1 - psi) * xbar + psi * v[, n + 1]
      fxcc <- fun(xcc, ...)
      nfev <- nfev + 1
      if (fxcc < fv[n + 1]) {
        v[, n + 1] <- xcc
        fv[n + 1] <- fxcc
      } else {
        shrink <- TRUE
      }
    }
    if (shrink) {
      for (j in 2:(n + 1)) {
        v[, j] <- v[, 1] + sigma * (v[, j] - v[, 1])
        fv[j] <- fun(v[, j], ...)
      }
      nfev <- nfev + n
    }
    ord <- order(fv)
    fv <- fv[ord]
    v <- v[, ord, drop = FALSE]
    iter <- iter + 1
  }
  list(par = v[, 1], value = fv[1], iterations = iter, fun_evals = nfev)
}
