#' Scatter plots
#'
#' Scatter plot of two series with the least squares line or, for
#' `series = "all"`, the matrix of scatter plots with histograms in the
#' diagonal.
#'
#' @param y Time series data (see [as_tsx_matrix()]), at least two series.
#' @param bins Number of bins of the histograms. Default
#'   `ceiling(sqrt(T))`.
#' @param series Two series (indices or names; the first one on the
#'   horizontal axis) or `"all"`.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vscatter` with fields `call`, `series`,
#'   `data` (matrix of the series) and `coef`, a data.frame with the least
#'   squares lines of every ordered pair: `x`, `y`, `intercept`, `slope`.
#' @examples
#' plot(vscatter(scc))
#' plot(vscatter(scc, series = "all"))
#' @export
vscatter <- function(y, bins = NULL, series = c(1, 2), names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  if (m < 2) stop("'vscatter' needs at least two series.", call. = FALSE)
  if (is.null(bins)) bins <- ceiling(sqrt(n))
  idx <- tsx_series_index(series, y, allow_all = TRUE)
  all <- is.character(series) && tolower(series[1]) == "all"
  if (!all && length(idx) < 2) stop("Give two series or \"all\".", call. = FALSE)
  if (!all) idx <- idx[1:2]
  coef <- NULL
  for (i in seq_len(m)) {
    for (j in seq_len(m)) {
      if (i == j) next
      b <- tsx_line_fit(y[, i], y[, j])
      coef <- rbind(coef, data.frame(x = colnames(y)[i], y = colnames(y)[j],
                                     intercept = b[1], slope = b[2], stringsAsFactors = FALSE))
    }
  }
  rownames(coef) <- NULL
  tsx_result("vscatter", call = list(bins = bins, series = idx, all = all),
             series = colnames(y)[idx], data = y[, idx, drop = FALSE], coef = coef)
}

# Least squares line of y on x (missing values handled with nanprod).
tsx_line_fit <- function(x, y) {
  xm <- cbind(1, x)
  if (anyNA(x) || anyNA(y)) {
    as.vector(solve(tsx_nanprod(t(xm), xm)$prod) %*% tsx_nanprod(t(xm), y)$prod)
  } else {
    as.vector(qr.solve(xm, y))
  }
}

#' @export
plot.tsx_vscatter <- function(x, ...) {
  d <- x$data
  if (!x$call$all) {
    b <- x$coef[x$coef$x == x$series[1] & x$coef$y == x$series[2], ]
    graphics::plot(d[, 1], d[, 2], pch = 8, col = "blue", xlab = x$series[1],
                   ylab = x$series[2],
                   main = paste0("Scatter Plot: Series ", x$series[1], " vs ", x$series[2]))
    graphics::abline(b$intercept, b$slope, col = "red")
  } else {
    m <- ncol(d)
    op <- graphics::par(mfrow = c(m, m), mar = c(0.5, 0.5, 0.5, 0.5), oma = c(3, 3, 3, 1))
    on.exit(graphics::par(op))
    for (i in seq_len(m)) {
      for (j in seq_len(m)) {
        if (i == j) {
          tsx_hist_plot(d[, i], x$call$bins, axes = FALSE)
        } else {
          b <- x$coef[x$coef$x == x$series[j] & x$coef$y == x$series[i], ]
          graphics::plot(d[, j], d[, i], pch = 20, col = "blue", axes = FALSE, xlab = "",
                         ylab = "")
          graphics::box()
          graphics::abline(b$intercept, b$slope, col = "red")
        }
        if (i == m) graphics::mtext(x$series[j], side = 1, line = 1, cex = 0.8)
        if (j == 1) graphics::mtext(x$series[i], side = 2, line = 1, cex = 0.8)
      }
    }
    graphics::mtext("Scatter Plots for All Series", side = 3, outer = TRUE, line = 1)
  }
  invisible(x)
}

#' @export
print.tsx_vscatter <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = "Least squares lines (y = intercept + slope * x)",
                table = tsx_format_table(x$coef, digits,
                                         col_names = c("x", "y", "Intercept", "Slope")))
  invisible(x)
}

#' Histogram with gaussian and non-parametric density estimates
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param bins Number of bins. Default `ceiling(sqrt(T))`.
#' @param series Series to analyse (index or name).
#' @param names Optional names of the series.
#' @return An object of class `tsx_vhist` with fields `call`, `series`,
#'   `hist` (data.frame with bin `mid`, `lower`, `upper` and `count`) and
#'   `density` (data.frame with `x`, `normal` and `kernel`, both scaled to
#'   counts).
#' @examples
#' plot(vhist(vdif(log(airpas), c(1, 1), c(1, 12))))
#' @export
vhist <- function(y, bins = NULL, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  if (is.null(bins)) bins <- ceiling(sqrt(nrow(y)))
  bins <- tsx_check_int(bins, "bins")
  i <- tsx_series_index(series, y)[1]
  d <- tsx_hist_data(y[, i], bins)
  tsx_result("vhist", call = list(bins = bins, series = i), series = colnames(y)[i],
             hist = d$hist, density = d$density)
}

# Histogram, normal density and kernel density.
tsx_hist_data <- function(z, bins) {
  z <- z[!is.na(z)]
  n <- length(z)
  h <- tsx_hist(z, bins)
  rz <- max(z) - min(z)
  xaxis <- seq(min(h$breaks), max(h$breaks), length.out = 181)
  normal <- n * stats::dnorm(xaxis, mean(z), stats::sd(z)) * (rz / bins)
  kern <- tsx_ksdensity(z, xaxis) * rz * n / bins
  list(hist = data.frame(mid = h$mids, lower = h$breaks[-length(h$breaks)],
                         upper = h$breaks[-1], count = h$counts),
       density = data.frame(x = xaxis, normal = normal, kernel = kern))
}

tsx_hist_plot <- function(z, bins, axes = TRUE, main = "", xlab = "", ylab = "") {
  d <- tsx_hist_data(z, bins)
  hh <- d$hist
  ylim <- c(0, max(hh$count, d$density$normal, d$density$kernel))
  graphics::plot(NA, xlim = range(c(hh$lower, hh$upper)), ylim = ylim, axes = axes,
                 main = main, xlab = xlab, ylab = ylab)
  graphics::rect(hh$lower, 0, hh$upper, hh$count, col = "lightsteelblue", border = "navy")
  graphics::lines(d$density$x, d$density$normal, col = "red", lwd = 2)
  graphics::lines(d$density$x, d$density$kernel, col = "green3", lwd = 2)
  if (!axes) graphics::box()
}

#' @export
plot.tsx_vhist <- function(x, ...) {
  hh <- x$hist
  dd <- x$density
  ylim <- c(0, max(hh$count, dd$normal, dd$kernel))
  graphics::plot(NA, xlim = range(c(hh$lower, hh$upper)), ylim = ylim,
                 main = paste0("Series ", x$series,
                               ": Histogram, Nonparametric estimate(green) & Theoretical normal(red)"),
                 xlab = paste("Series", x$series), ylab = "Data points", cex.main = 0.85)
  graphics::rect(hh$lower, 0, hh$upper, hh$count, col = "lightsteelblue", border = "navy")
  graphics::lines(dd$x, dd$normal, col = "red", lwd = 2)
  graphics::lines(dd$x, dd$kernel, col = "green3", lwd = 2)
  invisible(x)
}

#' @export
print.tsx_vhist <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = paste0("Series ", x$series, ": Histogram"),
                table = tsx_format_table(x$hist, c(digits, digits, digits, 0)))
  invisible(x)
}

#' Normal QQ plot
#'
#' Empirical quantiles of one series against the quantiles of a normal
#' distribution with the same mean and standard deviation, with the line
#' through the 25% and 75% quartiles.
#'
#' @inheritParams vhist
#' @return An object of class `tsx_vqqplot` with fields `call`, `series`,
#'   `table` (data.frame with `theoretical` and `empirical` quantiles),
#'   `quartiles` (x and y coordinates of the quartiles) and `line` (end points
#'   of the reference line).
#' @examples
#' plot(vqqplot(vdif(log(airpas), c(1, 1), c(1, 12))))
#' @export
vqqplot <- function(y, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  i <- tsx_series_index(series, y)[1]
  zi <- sort(y[!is.na(y[, i]), i])
  n <- length(zi)
  qt <- stats::qnorm((seq_len(n) - 0.5) / n, mean(zi), stats::sd(zi))
  x1 <- as.vector(tsx_prctile(qt, c(25, 75)))
  y1 <- as.vector(tsx_prctile(zi, c(25, 75)))
  beta <- diff(y1) / diff(x1)
  yini <- y1[1] - (x1[1] - qt[1]) * beta
  yend <- y1[2] + (qt[n] - x1[2]) * beta
  tsx_result("vqqplot", call = list(series = i), series = colnames(y)[i],
             table = data.frame(theoretical = qt, empirical = zi),
             quartiles = list(x = x1, y = y1),
             line = list(x = c(qt[1], qt[n]), y = c(yini, yend)))
}

#' @export
plot.tsx_vqqplot <- function(x, ...) {
  t <- x$table
  graphics::plot(t$theoretical, t$empirical, pch = 8,
                 main = paste0("Series ", x$series,
                               ": Empirical Quantiles vs Gaussian Theoretical Quantiles"),
                 xlab = "Normal Theoretical Quantiles", ylab = "Empirical Quantiles",
                 cex.main = 0.9)
  graphics::lines(x$line$x, x$line$y, col = "red", lty = 3)
  graphics::lines(x$quartiles$x, x$quartiles$y, col = "red", lwd = 2, type = "b", pch = 1)
  invisible(x)
}

#' @export
print.tsx_vqqplot <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = paste0("Series ", x$series, ": QQ plot"),
                table = tsx_format_table(x$table, digits,
                                         col_names = c("Theoretical", "Empirical")))
  invisible(x)
}
