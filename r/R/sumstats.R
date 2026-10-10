#' Summary descriptive statistics
#'
#' Computes for every series the number of data points, missing values,
#' percentiles, means (arithmetic, geometric and harmonic), dispersion
#' measures, skewness and kurtosis, a test of zero mean and, for more than one
#' series, the correlation matrix.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param gaussian If `TRUE` (default) the probability of zero mean is
#'   computed from the t distribution; if `FALSE` it is estimated by
#'   bootstrap (`nsimul` replications) smoothed with a kernel density.
#' @param nsimul Number of bootstrap replications when `gaussian = FALSE`.
#' @param digits Number of decimals for printing.
#' @param seed Optional seed for the bootstrap (the global random number
#'   generator state is restored on exit).
#' @param names Optional names of the series.
#' @return An object of class `tsx_sumstats` with fields:
#'   * `call`: options used,
#'   * `series`: names of the series,
#'   * `stats`: data.frame with one row per series and columns `n`,
#'     `missing`, `min`, `p10`, `p25`, `mean`, `p_mean_zero`,
#'     `geometric_mean`, `harmonic_mean`, `median`, `mode`, `p75`, `p90`,
#'     `max`, `iqr`, `range`, `sd`, `var`, `mean_abs_dev`, `median_abs_dev`,
#'     `mean_sd_ratio`, `skewness`, `kurtosis` (excess kurtosis).
#'     `p_mean_zero` is the two sided p-value of the test of zero mean and
#'     `range` is `max - min`. `mode` is the most frequent value (the smallest
#'     one in case of ties; with continuous data with no
#'     repeated values it equals the minimum),
#'   * `cor`: correlation matrix (`NULL` for one series) and `se_cor` its
#'     standard error \eqn{1/\sqrt{T}}.
#' @examples
#' sumstats(airpas)
#' sumstats(scc, names = c("A", "B", "C"))
#' @export
sumstats <- function(y, gaussian = TRUE, nsimul = 3000, digits = 4,
                     seed = NULL, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n_obs <- nrow(y)
  m <- ncol(y)
  st <- data.frame(series = colnames(y), stringsAsFactors = FALSE)
  pick <- function(f) vapply(seq_len(m), function(i) f(y[!is.na(y[, i]), i]), numeric(1))
  st$n <- rep(n_obs, m)
  st$missing <- colSums(is.na(y))
  st$min <- pick(min)
  st$p10 <- pick(function(x) tsx_prctile(x, 10)[1])
  st$p25 <- pick(function(x) tsx_prctile(x, 25)[1])
  st$mean <- pick(mean)
  st$p_mean_zero <- NA_real_
  st$geometric_mean <- pick(function(x) if (all(x > 0)) exp(mean(log(x))) else NA_real_)
  st$harmonic_mean <- pick(function(x) {
    x <- x[abs(x) > 1e-5]
    1 / (sum(1 / x) / length(x))
  })
  st$median <- pick(stats::median)
  st$mode <- pick(tsx_mode)
  st$p75 <- pick(function(x) tsx_prctile(x, 75)[1])
  st$p90 <- pick(function(x) tsx_prctile(x, 90)[1])
  st$max <- pick(max)
  st$iqr <- st$p75 - st$p25
  st$range <- st$max - st$min
  st$sd <- pick(stats::sd)
  st$var <- st$sd^2
  st$mean_abs_dev <- pick(function(x) mean(abs(x - mean(x))))
  st$median_abs_dev <- meda(y)
  st$mean_sd_ratio <- st$mean / st$sd
  st$skewness <- pick(tsx_skewness)
  st$kurtosis <- pick(tsx_kurtosis) - 3
  nn <- st$n - st$missing
  tstat <- st$mean / (st$sd / sqrt(nn))
  if (gaussian) {
    st$p_mean_zero <- 2 * stats::pt(abs(tstat), nn - 1, lower.tail = FALSE)
  } else {
    st$p_mean_zero <- tsx_with_seed(seed, tsx_auxsumstats(y, tstat, nsimul))
  }
  rownames(st) <- NULL
  cor <- NULL
  if (m > 1) {
    cor <- tsx_nancorr(y)
    dimnames(cor) <- list(colnames(y), colnames(y))
  }
  tsx_result("sumstats",
             call = list(gaussian = gaussian, nsimul = nsimul, digits = digits,
                         seed = seed),
             series = colnames(y), stats = st, cor = cor,
             se_cor = 1 / sqrt(n_obs))
}

# Evaluate 'expr' with a given seed, restoring the RNG state afterwards.
tsx_with_seed <- function(seed, expr) {
  if (is.null(seed)) return(expr)
  genv <- globalenv()
  old <- if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
    get(".Random.seed", envir = genv, inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
        rm(".Random.seed", envir = genv)
      }
    } else {
      assign(".Random.seed", old, envir = genv)
    }
  })
  set.seed(seed)
  force(expr)
}

# Bootstrap probability of zero mean (two sided: twice the
# bootstrap probability of a statistic of the opposite sign).
tsx_auxsumstats <- function(y, stats, nsimul) {
  n <- nrow(y)
  m <- ncol(y)
  bins <- ceiling(sqrt(n))
  simul <- matrix(NA_real_, nsimul, m)
  for (i in seq_len(nsimul)) {
    zi <- y[sample.int(n, n, replace = TRUE), , drop = FALSE]
    simul[i, ] <- colMeans(zi, na.rm = TRUE) /
      (apply(zi, 2, stats::sd, na.rm = TRUE) / sqrt(n))
  }
  out <- rep(NA_real_, m)
  for (i in seq_len(m)) {
    zi <- simul[, i]
    zi <- zi[is.finite(zi)]
    centers <- tsx_hist(zi, bins)$mids
    lim <- c(floor(min(centers)), ceiling(max(centers)))
    xaxis <- seq(lim[1], lim[2], length.out = 181)
    fi <- cumsum(tsx_ksdensity(zi, xaxis))
    fi <- fi / max(fi)
    r <- tsx_interpol(xaxis, fi, 0)
    if (stats[i] < 0) r <- 1 - r
    out[i] <- min(1, max(0, 2 * r))
  }
  out
}

# Histogram counts with 'bins' equally spaced bins between min and max.
tsx_hist <- function(x, bins) {
  x <- x[!is.na(x)]
  mn <- min(x)
  mx <- max(x)
  if (mn == mx) {
    mn <- mn - bins / 2
    mx <- mx + bins / 2
  }
  breaks <- seq(mn, mx, length.out = bins + 1)
  counts <- numeric(bins)
  idx <- findInterval(x, breaks, rightmost.closed = TRUE, all.inside = TRUE)
  for (k in idx) counts[k] <- counts[k] + 1
  list(breaks = breaks, counts = counts,
       mids = (breaks[-1] + breaks[-length(breaks)]) / 2)
}

# Kernel density estimate with normal kernel and bandwidth
# sigma * (4 / (3 n))^(1 / 5), sigma = MAD / 0.6745.
tsx_ksdensity <- function(x, at) {
  x <- x[!is.na(x)]
  n <- length(x)
  sig <- stats::median(abs(x - stats::median(x))) / 0.6745
  if (sig <= 0) sig <- max(x) - min(x)
  h <- if (sig > 0) sig * (4 / (3 * n))^(1 / 5) else 1
  vapply(at, function(a) mean(stats::dnorm((a - x) / h)) / h, numeric(1))
}

#' @export
print.tsx_sumstats <- function(x, digits = x$call$digits, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  st <- x$stats
  lab <- c("Data points:", "Missing:", "Minimum:", "10% percentile:",
           "25% percentile:", "Mean:",
           if (isTRUE(x$call$gaussian)) "P(Mean= 0, Gaussian):" else "P(Mean= 0, Empirical):",
           "Geometric Mean:", "Harmonic Mean:", "Median:", "Mode:", "75% percentile:",
           "90% percentile:", "Maximum:", "Interquartile Range:", "Range:",
           "Standard Deviation:", "Variance:", "Mean Absolute Deviation:",
           "Median Absolute Deviation:", "Mean/Standard Deviation:",
           "Skewness:", "Kurtosis (-3):")
  vals <- t(as.matrix(st[, -1]))
  colnames(vals) <- x$series
  dig <- matrix(digits, nrow(vals), ncol(vals))
  dig[1:2, ] <- 0
  tab <- vapply(seq_len(ncol(vals)), function(j) {
    vapply(seq_len(nrow(vals)), function(i) {
      if (is.na(vals[i, j])) "NA" else formatC(vals[i, j], format = "f", digits = dig[i, j])
    }, character(1))
  }, character(nrow(vals)))
  tab <- matrix(tab, nrow(vals))
  w <- max(nchar(c(tab, x$series)))
  lw <- max(nchar(lab))
  head <- paste(formatC("", width = -lw), paste(formatC(x$series, width = w), collapse = "  "))
  body <- paste(formatC(lab, width = -lw),
                apply(tab, 1, function(r) paste(formatC(r, width = w), collapse = "  ")))
  width <- max(nchar(c(head, body)))
  rule <- strrep("-", width)
  cat(rule, head, rule, body[1:2], rule, body[3:14], rule, body[15:21], rule,
      body[22:23], rule, sep = "\n")
  if (!is.null(x$cor)) {
    cm <- x$cor
    marks <- matrix(tsx_signif_marks(cm / x$se_cor), nrow(cm))
    tabc <- tsx_format_table(as.data.frame(cm), digits, row_names = x$series,
                             col_names = x$series)
    mk <- c("", apply(marks, 1, paste, collapse = ""))
    cat("\n", "Correlation Matrix:", "\n", sep = "")
    cat(paste(tabc, " | ", mk), sep = "\n")
  }
  invisible(x)
}

# Most frequent value (the smallest one in case of ties).
tsx_mode <- function(x) {
  x <- sort(x)
  if (length(x) == 0) return(NA_real_)
  r <- rle(x)
  r$values[which.max(r$lengths)]
}
