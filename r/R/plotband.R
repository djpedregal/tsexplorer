#' Time series plot with confidence bands
#'
#' Plot of one series with its mean and mean +/- 2 standard deviations, of a
#' subsample of length `s`, of all the subsamples of length `s` overlaid, or
#' of all the series together (optionally standardised).
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param s Length of the subsamples (seasonal period). Default 12.
#' @param standard For `series = "all"`, plot the standardised series.
#' @param fixed Keep the vertical scale of the full sample when plotting a
#'   subsample.
#' @param series One series (index or name) or `"all"`.
#' @param subsample `0` for the full sample, `k` for the k-th subsample of
#'   length `s` (observations `(k - 1) * s + 1` to `k * s`).
#' @param overlay For one series, plot all the subsamples of length `s`
#'   overlaid (one line per subsample).
#' @param names Optional names of the series.
#' @return An object of class `tsx_plotband` with fields `call`, `series`,
#'   `data` (the data to plot: a matrix whose rows are the time indices
#'   `time`), `time`, `dates` (dates of `time` for dated inputs, `NULL`
#'   otherwise or with `overlay`), `mean`, `sd` and `ylim`.
#' @examples
#' plot(plotband(airpas))
#' plot(plotband(airpas, overlay = TRUE))
#' plot(plotband(scc, series = "all", standard = TRUE))
#' @export
plotband <- function(y, s = 12, standard = FALSE, fixed = TRUE, series = 1, subsample = 0,
                     overlay = FALSE, names = NULL) {
  y <- as_tsx_matrix(y, names)
  dates <- attr(y, "dates")
  n <- nrow(y)
  s <- min(tsx_check_int(s, "s"), n)
  nsub <- ceiling(n / s)
  subsample <- min(max(0, round(subsample)), nsub)
  idx <- tsx_series_index(series, y, allow_all = TRUE)
  all_series <- length(idx) > 1 || (is.character(series) && tolower(series[1]) == "all")
  t <- if (subsample == 0) seq_len(n) else ((subsample - 1) * s + 1):min(subsample * s, n)
  if (!all_series) {
    z <- y[, idx]
    zm <- mean(z, na.rm = TRUE)
    zs <- stats::sd(z, na.rm = TRUE)
    if (overlay) {
      dat <- matrix(c(z, rep(NA, nsub * s - n)), nrow = s)
      colnames(dat) <- paste0("sub", seq_len(nsub))
      t <- seq_len(s)
      ylim <- c(min(zm - 2 * zs, dat, na.rm = TRUE), max(zm + 2 * zs, dat, na.rm = TRUE))
    } else {
      dat <- matrix(z[t], ncol = 1, dimnames = list(NULL, colnames(y)[idx]))
      ref <- if (fixed) z else z[t]
      ylim <- c(min(zm - 2 * zs, ref, na.rm = TRUE), max(zm + 2 * zs, ref, na.rm = TRUE))
    }
  } else {
    z <- y[, idx, drop = FALSE]
    if (standard) z <- tsx_standardize(z)
    zm <- if (standard) 0 else NA_real_
    zs <- if (standard) 1 else NA_real_
    dat <- z[t, , drop = FALSE]
    ylim <- if (fixed) range(z, na.rm = TRUE) else range(dat, na.rm = TRUE)
  }
  if (ylim[1] == ylim[2]) ylim <- ylim + c(-1, 1)
  pdates <- if (all_series || !overlay) dates[t] else NULL
  tsx_result("plotband",
             call = list(s = s, standard = standard, fixed = fixed, series = idx,
                         subsample = subsample, overlay = overlay, all = all_series),
             series = colnames(y)[idx], data = dat, time = t, dates = pdates, mean = zm, sd = zs,
             ylim = ylim, n_subsamples = nsub)
}

#' @export
plot.tsx_plotband <- function(x, ...) {
  cl <- x$call
  co <- tsx_time_coords(x$dates, x$time)
  if (!cl$all) {
    lab <- x$series
    main <- if (cl$overlay) paste0("Series ", lab, ": Series plot every ", cl$s, " samples")
            else paste0("Series ", lab, ": Series Plot with 2*S.D. bands")
    graphics::matplot(co$x, x$data, type = "l", lty = 1,
                      col = if (cl$overlay) grDevices::rainbow(ncol(x$data)) else "black",
                      xlim = co$xlim, ylim = x$ylim, xaxt = "n", xlab = co$lab,
                      ylab = paste("Series", lab), main = main)
    co$axis()
    graphics::abline(h = x$mean, col = "red")
    graphics::abline(h = x$mean + c(-2, 2) * x$sd, col = "red", lty = 3)
  } else {
    cols <- grDevices::hcl.colors(ncol(x$data), "Dark 3")
    graphics::matplot(co$x, x$data, type = "l", lty = 1, col = cols, xlim = co$xlim,
                      ylim = x$ylim, xaxt = "n", xlab = co$lab,
                      ylab = if (cl$standard) "Standard scale" else "Units",
                      main = if (cl$standard) "Standardised Plot of All Series with 2*S.D. bands"
                             else "Plot of All Series")
    co$axis()
    if (cl$standard) {
      graphics::abline(h = 0, col = "red")
      graphics::abline(h = c(-2, 2), col = "red", lty = 3)
    }
    graphics::legend("topleft", x$series, col = cols, lty = 1, bty = "n", cex = 0.8)
  }
  invisible(x)
}

#' Box plot of a time series by groups of `s` consecutive observations
#'
#' For each group of `s` consecutive observations (e.g. each year of monthly
#' data) shows the mean, median, 25% and 75% percentiles, minimum and maximum.
#' Optionally highlights the observations of one position within the groups
#' (e.g. one month across years).
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param s Length of the groups (seasonal period). Default 12, limited to
#'   `T / 2`.
#' @param series Series to analyse (index or name).
#' @param highlight `0` for none, or the position `1..s` within the groups
#'   whose values are highlighted.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vboxplot` with fields `call`, `series`,
#'   `stats` (data.frame with columns `group`, `mean`, `median`, `p25`, `p75`,
#'   `min`, `max`), `highlight` (values highlighted, one per group) and
#'   `group_dates` (date of the first observation of each group for dated
#'   inputs, otherwise `NULL`).
#' @examples
#' plot(vboxplot(airpas, highlight = 7))
#' @export
vboxplot <- function(y, s = 12, series = 1, highlight = 0, names = NULL) {
  y <- as_tsx_matrix(y, names)
  dates <- attr(y, "dates")
  n <- nrow(y)
  s <- min(tsx_check_int(s, "s"), floor(n / 2))
  i <- tsx_series_index(series, y)[1]
  ng <- ceiling(n / s)
  zi <- matrix(c(y[, i], rep(NA, ng * s - n)), nrow = s)
  st <- tsx_group_stats(zi)
  highlight <- min(max(0, round(highlight)), s)
  hv <- if (highlight > 0) y[seq(highlight, n, by = s), i] else numeric(0)
  tsx_result("vboxplot", call = list(s = s, series = i, highlight = highlight),
             series = colnames(y)[i], stats = data.frame(group = seq_len(ng), st),
             highlight = hv, group_dates = dates[seq(1, n, by = s)])
}

#' Transpose box plot of a time series
#'
#' Standardises each group of `s` consecutive observations and shows, for
#' each position `1..s` within the groups (e.g. each month), the mean,
#' median, 25% and 75% percentiles, minimum and maximum across groups.
#' Optionally highlights one group (e.g. one year).
#'
#' @inheritParams vboxplot
#' @param highlight `0` for none, or the group `1..ceiling(T / s)` to
#'   highlight.
#' @return An object of class `tsx_vtboxplot` with fields `call`, `series`,
#'   `stats` (data.frame with columns `position`, `mean`, `median`, `p25`,
#'   `p75`, `min`, `max`), `data` (matrix `s x groups` of standardised values)
#'   and `highlight`.
#' @examples
#' plot(vtboxplot(airpas, highlight = 12))
#' @export
vtboxplot <- function(y, s = 12, series = 1, highlight = 0, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  s <- min(tsx_check_int(s, "s"), floor(n / 2))
  i <- tsx_series_index(series, y)[1]
  ng <- ceiling(n / s)
  zi <- tsx_standardize(matrix(c(y[, i], rep(NA, ng * s - n)), nrow = s))
  st <- tsx_group_stats(t(zi))
  highlight <- min(max(0, round(highlight)), ng)
  hv <- if (highlight > 0) zi[, highlight] else numeric(0)
  tsx_result("vtboxplot", call = list(s = s, series = i, highlight = highlight),
             series = colnames(y)[i], stats = data.frame(position = seq_len(s), st),
             data = zi, highlight = hv)
}

# Column statistics of a matrix (columns are the groups).
tsx_group_stats <- function(z) {
  data.frame(mean = colMeans(z, na.rm = TRUE),
             median = apply(z, 2, stats::median, na.rm = TRUE),
             p25 = as.vector(tsx_prctile(z, 25)),
             p75 = as.vector(tsx_prctile(z, 75)),
             min = apply(z, 2, function(v) if (all(is.na(v))) NA else min(v, na.rm = TRUE)),
             max = apply(z, 2, function(v) if (all(is.na(v))) NA else max(v, na.rm = TRUE)))
}

tsx_plot_boxstats <- function(xv, st, hv, main, xlab, ylab, labels = NULL) {
  ylim <- range(c(st$min, st$max, hv), na.rm = TRUE)
  graphics::plot(xv, st$mean, type = "l", col = "red", lwd = 2, xlim = c(0, max(xv) + 1),
                 ylim = ylim, xaxt = if (is.null(labels)) "s" else "n", xlab = xlab,
                 ylab = ylab, main = main)
  if (!is.null(labels)) graphics::axis(1, at = xv, labels = labels)
  graphics::lines(xv, st$median, lwd = 2)
  graphics::lines(xv, st$p25, col = "red", lty = 3)
  graphics::lines(xv, st$p75, col = "red", lty = 3)
  graphics::points(xv, st$min, pch = 8, col = "blue")
  graphics::points(xv, st$max, pch = 8, col = "blue")
  if (length(hv)) graphics::lines(seq_along(hv), hv, type = "b", pch = 20)
  graphics::legend("topleft", c("Mean", "Median", "25% and 75% Percentiles",
                                "Maximum and Minimum"),
                   col = c("red", "black", "red", "blue"), lty = c(1, 1, 3, NA),
                   lwd = c(2, 2, 1, NA), pch = c(NA, NA, NA, 8), bty = "n", cex = 0.8)
}

#' @export
plot.tsx_vboxplot <- function(x, ...) {
  s <- x$call$s
  dated <- !is.null(x$group_dates)
  tsx_plot_boxstats(x$stats$group, x$stats, x$highlight,
                    paste0("Series ", x$series, ": Box Plot (every ", s, " samples apart)"),
                    if (dated) paste0("Groups of ", s, " samples (start date)")
                    else paste0("Groups of every ", s, " samples apart"),
                    paste("Values of Series", x$series),
                    labels = if (dated) tsx_format_dates(x$group_dates))
  invisible(x)
}

#' @export
plot.tsx_vtboxplot <- function(x, ...) {
  s <- x$call$s
  tsx_plot_boxstats(x$stats$position, x$stats, x$highlight,
                    paste0("Series ", x$series, ": Transpose Box Plot (", s, " samples)"),
                    paste0("Groups of ", s, " samples"),
                    paste("Values of Series", x$series))
  invisible(x)
}

#' @export
print.tsx_vboxplot <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  st <- x$stats
  if (!is.null(x$group_dates)) {
    st <- data.frame(group = st$group, start = tsx_format_dates(x$group_dates), st[-1])
  }
  tsx_cat_block(title = paste0("Series ", x$series, ": Box Plot (every ", x$call$s,
                               " samples apart)"),
                table = tsx_format_table(st, c(0, rep(digits, ncol(st) - 1))))
  invisible(x)
}

#' @export
print.tsx_vtboxplot <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = paste0("Series ", x$series, ": Transpose Box Plot (", x$call$s,
                               " samples, standardised)"),
                table = tsx_format_table(x$stats, c(0, rep(digits, 6))))
  invisible(x)
}
