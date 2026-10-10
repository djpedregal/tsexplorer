#' CUSUM and CUSUM of squares tests
#'
#' Cumulative sums of the standardised series (CUSUM) and of its squared
#' deviations from the mean (CUSUMSQ), with 5% confidence bands.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param series Series to analyse (index or name).
#' @param names Optional names of the series.
#' @return An object of class `tsx_vcusum` with fields `call`, `series` and
#'   `table`, a data.frame with columns `t`, `cusum`, `cusum_lower`,
#'   `cusum_upper`, `cusumsq`, `cusumsq_lower`, `cusumsq_upper`, and `dates`
#'   (dates of the rows for dated inputs, otherwise `NULL`).
#' @references
#' Brown, R.L., Durbin, J. and Evans, J.M. (1975). Techniques for testing the
#' constancy of regression relationships over time. *Journal of the Royal
#' Statistical Society B*, 37, 149-192.
#' @examples
#' plot(vcusum(vdif(log(airpas), c(1, 1), c(1, 12))))
#' @export
vcusum <- function(y, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  dates <- attr(y, "dates")
  n <- nrow(y)
  i <- tsx_series_index(series, y)[1]
  z <- y[, i]
  ok <- !is.na(z)
  zm <- z[ok] - mean(z[ok])
  cusum <- cusumsq <- rep(NA_real_, n)
  cusum[ok] <- cumsum(zm / stats::sd(z[ok]))
  cusumsq[ok] <- cumsum(zm^2 / sum(zm^2))
  t <- seq_len(n)
  band <- 0.948 * sqrt(n) + 2 * 0.948 * t / sqrt(n)
  tab <- data.frame(t = t, cusum = cusum, cusum_lower = -band, cusum_upper = band,
                    cusumsq = cusumsq, cusumsq_lower = -0.32894 + t / n,
                    cusumsq_upper = 0.32894 + t / n)
  tsx_result("vcusum", call = list(series = i), series = colnames(y)[i], table = tab,
             dates = dates)
}

#' @export
plot.tsx_vcusum <- function(x, ...) {
  t <- x$table
  co <- tsx_time_coords(x$dates, t$t)
  op <- graphics::par(mfrow = c(2, 1), mar = c(4, 4, 2.5, 1))
  on.exit(graphics::par(op))
  graphics::matplot(co$x, cbind(t$cusum, t$cusum_lower, t$cusum_upper, 0), type = "l",
                    lty = c(1, 3, 3, 1), col = c("black", "red", "red", "red"), xlab = "",
                    xaxt = "n",
                    ylab = "CUSUM test",
                    main = paste0("Series ", x$series, ": CUSUM test with 5% Confidence Band"))
  co$axis()
  graphics::matplot(co$x, cbind(t$cusumsq, t$cusumsq_lower, t$cusumsq_upper), type = "l",
                    lty = c(1, 3, 3), col = c("black", "red", "red"), xlab = co$lab, xaxt = "n",
                    ylab = "CUSUMSQ test",
                    main = paste0("Series ", x$series, ": CUSUMSQ test with 5% Confidence Band"))
  co$axis()
  graphics::lines(range(co$x), range(t$cusumsq, na.rm = TRUE), col = "red")
  invisible(x)
}

#' @export
print.tsx_vcusum <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tab <- x$table
  if (!is.null(x$dates)) tab <- data.frame(t = tab$t, date = tsx_format_dates(x$dates), tab[-1])
  tsx_cat_block(title = paste0("Series ", x$series, ": CUSUM and CUSUMSQ tests"),
                table = tsx_format_table(tab, c(0, rep(digits, ncol(tab) - 1))))
  invisible(x)
}

#' Standard deviation - mean plots
#'
#' Splits the series into groups of `s` consecutive observations (the first
#' `T mod s` observations are discarded) and plots a dispersion measure
#' against a location measure of each group, with the least squares line. A
#' positive slope suggests a transformation to stabilise the variance.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param s Length of the groups (seasonal period). Default 12.
#' @param type `0`: standard deviation vs mean; `1`: MEDA vs median;
#'   `2`: range vs mean.
#' @param numbers Label each point with the number of its group in the plot.
#' @param series Series to analyse (index or name).
#' @param names Optional names of the series.
#' @return An object of class `tsx_stdmean` with fields `call`, `series`,
#'   `table` (data.frame with columns `group`, `location`, `dispersion`) and
#'   `coef` (intercept and slope of the least squares line).
#' @examples
#' plot(stdmean(airpas))
#' plot(stdmean(log(airpas), type = 1))
#' @export
stdmean <- function(y, s = 12, type = 0, numbers = TRUE, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  s <- tsx_check_int(s, "s", 2)
  i <- tsx_series_index(series, y)[1]
  i0 <- n %% s + 1
  ng <- (n - i0 + 1) / s
  if (ng < 2) stop("Not enough data for groups of length 's'.", call. = FALSE)
  zi <- matrix(y[i0:n, i], nrow = s)
  if (type == 0) {
    loc <- colMeans(zi, na.rm = TRUE)
    disp <- apply(zi, 2, stats::sd, na.rm = TRUE)
  } else if (type == 1) {
    loc <- apply(zi, 2, stats::median, na.rm = TRUE)
    disp <- vapply(seq_len(ng), function(k) stats::median(abs(zi[, k] - loc[k]), na.rm = TRUE),
                   numeric(1))
  } else {
    loc <- colMeans(zi, na.rm = TRUE)
    disp <- apply(zi, 2, max, na.rm = TRUE) - apply(zi, 2, min, na.rm = TRUE)
  }
  b <- tsx_line_fit(loc, disp)
  tsx_result("stdmean", call = list(s = s, type = type, numbers = numbers, series = i),
             series = colnames(y)[i],
             table = data.frame(group = seq_len(ng), location = loc, dispersion = disp),
             coef = c(intercept = b[1], slope = b[2]))
}

#' @export
plot.tsx_stdmean <- function(x, ...) {
  lab <- switch(as.character(x$call$type),
                "0" = c("Mean", "Standard Deviation", "Standard Deviation - Mean Plot"),
                "1" = c("Median", "MEDA", "MEDA - Median Plot"),
                c("Mean", "Range", "Range - Mean Plot"))
  t <- x$table
  graphics::plot(t$location, t$dispersion, pch = 20, col = "blue", xlab = lab[1], ylab = lab[2],
                 main = paste0("Series ", x$series, ": ", lab[3]))
  graphics::abline(x$coef[1], x$coef[2], col = "red")
  if (isTRUE(x$call$numbers)) {
    inc <- diff(graphics::par("usr")[3:4]) / 30
    graphics::text(t$location, t$dispersion + inc, t$group, cex = 0.8)
  }
  invisible(x)
}

#' @export
print.tsx_stdmean <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = paste0("Series ", x$series, ": dispersion vs location by groups of ",
                               x$call$s),
                notes = sprintf("Least squares line: intercept %.4f, slope %.4f",
                                x$coef[1], x$coef[2]),
                table = tsx_format_table(x$table, c(0, digits, digits),
                                         col_names = c("Group", "Location", "Dispersion")))
  invisible(x)
}
