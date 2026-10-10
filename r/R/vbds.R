#' BDS test of independence
#'
#' Brock, Dechert and Scheinkman (BDS) test of the null hypothesis that a
#' series is independent and identically distributed, for embedding
#' dimensions `2:maxdim`. P-values are asymptotic (standard normal).
#'
#' The computations follow the implementation of Ludwig Kanzler (1998),
#' rewritten without the bitwise storage that program uses
#' to save memory.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param maxdim Maximum embedding dimension (at least 2). Default 2.
#' @param distance Dimensional distance as a fraction of the standard
#'   deviation of each series. Default 1.5. It is reduced to
#'   `min(0.9 * (max(y) - mean(y)) / sd(y))` (minimum over the series) if
#'   larger than that.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vbds` with fields `call` (effective
#'   `maxdim` and `distance`), `series` and `table`, a data.frame with columns
#'   `series`, `dim`, `w` (BDS statistic) and `p_value`.
#' @references
#' Brock, W.A., Dechert, W.D., Scheinkman, J.A. and LeBaron, B. (1996). A
#' test for independence based on the correlation dimension. *Econometric
#' Reviews*, 15, 197-235.
#'
#' Kanzler, L. (1999). Very fast and correctly sized estimation of the BDS
#' statistic. Working paper, University of Oxford.
#' @examples
#' vbds(vdif(log(airpas), c(1, 1), c(1, 12)), maxdim = 4)
#' @export
vbds <- function(y, maxdim = 2, distance = 1.5, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  maxdim <- min(tsx_check_int(maxdim, "maxdim", 2), floor(n / 2))
  # The limit is expressed, as 'distance', in standard deviations
  lim <- 0.9 * (apply(y, 2, max, na.rm = TRUE) - colMeans(y, na.rm = TRUE)) /
    apply(y, 2, stats::sd, na.rm = TRUE)
  distance <- min(distance, min(lim))
  tab <- NULL
  for (i in seq_len(ncol(y))) {
    b <- tsx_bds(y[!is.na(y[, i]), i], maxdim, distance)
    tab <- rbind(tab, data.frame(series = colnames(y)[i], dim = 2:maxdim, w = b$w,
                                 p_value = b$p_value, stringsAsFactors = FALSE))
  }
  tsx_result("vbds", call = list(maxdim = maxdim, distance = distance),
             series = colnames(y), table = tab)
}

# BDS statistic (Kanzler 1998) with epsilon = distance * sd(x).
# Closeness indicators are processed one lag (diagonal) at a time.
tsx_bds <- function(x, maxdim, distance) {
  n <- length(x)
  eps <- distance * stats::sd(x)
  fullsum <- rep(1, n)          # 1 + number of neighbours of each point
  pairs_from <- numeric(maxdim) # close pairs (i, j), i < j, with i >= m
  cm <- numeric(maxdim)         # close m-histories
  for (d in seq_len(n - 1)) {
    b <- abs(x[1:(n - d)] - x[(1 + d):n]) <= eps
    fullsum[1:(n - d)] <- fullsum[1:(n - d)] + b
    fullsum[(1 + d):n] <- fullsum[(1 + d):n] + b
    for (m in seq_len(maxdim)) {
      if (m <= n - d) pairs_from[m] <- pairs_from[m] + sum(b[m:(n - d)])
    }
    # a[t] = 1 if the m-histories ending at t and t + d are close:
    # a_m[t] = a_(m-1)[t] & b[t - m + 1], for t = m, ..., n - d
    len <- n - d
    a <- b
    for (m in 2:maxdim) {
      if (m > len) break
      idx <- m:len
      a_new <- logical(len)
      a_new[idx] <- a[idx] & b[idx - m + 1]
      a <- a_new
      cm[m] <- cm[m] + sum(a[idx])
    }
  }
  npairs <- function(k) k * (k + 1) / 2
  c1 <- vapply(seq_len(maxdim), function(m) pairs_from[m] / npairs(n - m), numeric(1))
  bitsum1 <- pairs_from[1]
  k <- (sum(fullsum^2) + 2 * n - 3 * (2 * bitsum1 + n)) / n / (n - 1) / (n - 2)
  w <- numeric(maxdim - 1)
  for (m in 2:maxdim) {
    cmm <- cm[m] / npairs(n - m)
    j <- seq_len(m - 1)
    sigma <- 2 * sqrt(k^m + 2 * sum(k^(m - j) * c1[1]^(2 * j)) + (m - 1)^2 * c1[1]^(2 * m) -
                        m^2 * k * c1[1]^(2 * m - 2))
    w[m - 1] <- sqrt(n - m + 1) * (cmm - c1[m]^m) / sigma
  }
  list(w = w, p_value = 2 * pmin(stats::pnorm(w), 1 - stats::pnorm(w)), c1 = c1, k = k)
}

#' @export
print.tsx_vbds <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  multi <- length(x$series) > 1
  tsx_cat_block(
    title = "Brock, Dechert & Scheinkman (BDS) Test",
    notes = c("H0: Process is linear and i.i.d.",
              paste("Distance as a fraction of the S.D.:", format(x$call$distance))),
    table = tsx_format_table(x$table[, c("dim", "w", "p_value")], c(0, digits, digits),
                             row_names = if (multi) x$table$series,
                             col_names = c("Dim", "BDS", "P-value")))
  invisible(x)
}
