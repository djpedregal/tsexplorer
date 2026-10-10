#' Cumulative periodogram
#'
#' Normalised cumulative periodogram of one series with the 1% and 5%
#' Kolmogorov-Smirnov bands of the white noise hypothesis.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param series Series to analyse (index or name).
#' @param names Optional names of the series.
#' @return An object of class `tsx_vcumperiod` with fields `call`, `series`,
#'   `table` (data.frame with columns `freq`, frequency in cycles per period
#'   from 0 to 0.5, and `cum_periodogram`) and `bands` (half width of the 1%
#'   and 5% bands).
#' @references
#' Box, G.E.P., Jenkins, G.M., Reinsel, G.C. and Ljung, G.M. (2015). *Time
#' Series Analysis: Forecasting and Control*, 5th ed. Wiley.
#' @examples
#' plot(vcumperiod(vdif(log(airpas), c(1, 1), c(1, 12))))
#' @export
vcumperiod <- function(y, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  i <- tsx_series_index(series, y)[1]
  z <- y[, i] - mean(y[, i], na.rm = TRUE)
  t2 <- floor(n / 2)
  w <- 2 * pi * (0:t2) / n
  per <- tsx_periodogram(z, w)
  cum <- cumsum(per)
  if (!is.na(cum[length(cum)])) cum <- cum / cum[length(cum)]
  tsx_result("vcumperiod", call = list(series = i), series = colnames(y)[i],
             table = data.frame(freq = w / (2 * pi), cum_periodogram = cum),
             bands = c(p01 = 1.63 / sqrt(t2), p05 = 1.36 / sqrt(t2)))
}

# Periodogram ordinates 2/T |sum z_t exp(-i w t)|^2 (missing values skipped).
tsx_periodogram <- function(z, w) {
  n <- length(z)
  tt <- seq_len(n)
  ok <- !is.na(z)
  vapply(w, function(wj) {
    a <- sum(z[ok] * cos(wj * tt[ok]))
    b <- sum(z[ok] * sin(wj * tt[ok]))
    2 / n * (a^2 + b^2)
  }, numeric(1))
}

#' @export
print.tsx_vcumperiod <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = paste0("Series ", x$series, ": Cumulative Periodogram"),
                notes = sprintf("Band half width: 1%% %.4f; 5%% %.4f", x$bands[1], x$bands[2]),
                table = tsx_format_table(x$table, digits, col_names = c("Frequency", "Cum. Power")))
  invisible(x)
}

#' @export
plot.tsx_vcumperiod <- function(x, ...) {
  t <- x$table
  b <- x$bands
  ylim <- c(min(t$cum_periodogram, -b[1], na.rm = TRUE), max(t$cum_periodogram, 1 + b[1], na.rm = TRUE))
  graphics::plot(t$freq, t$cum_periodogram, type = "l", xlim = c(0, 0.5), ylim = ylim,
                 xlab = "Frequency", ylab = "Cumulative Power",
                 main = paste0("Series ", x$series, ": Cumulative Periodogram (1% red; 5% black)"))
  graphics::lines(c(0, 0.5), c(0, 1), col = "red")
  graphics::lines(c(0, 0.5), c(b[1], 1 + b[1]), col = "red", lty = 3)
  graphics::lines(c(0, 0.5), c(-b[1], 1 - b[1]), col = "red", lty = 3)
  graphics::lines(c(0, 0.5), c(b[2], 1 + b[2]), col = "black", lty = 3)
  graphics::lines(c(0, 0.5), c(-b[2], 1 - b[2]), col = "black", lty = 3)
  invisible(x)
}

#' Spectrum, cross spectrum, gains and coherence
#'
#' Periodogram of one series, smoothed with a triangular window of length
#' `smooth`, or, for two series, the gains and squared coherence computed from
#' the smoothed cross periodogram. The periodogram is
#' \eqn{|\sum_t z_t e^{-i\omega t}|^2 / (2\pi T)} at the Fourier frequencies;
#' near the frequencies 0 and \eqn{\pi} the smoothing window uses the
#' symmetry of the periodogram.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param smooth Length of the triangular smoothing window (an even value is
#'   increased by one; 1 means no smoothing). Default 1.
#' @param xlog Logical vector of length 2: logarithmic scale for the
#'   frequency (period) axis and for the power axis in the plot. Default
#'   `c(FALSE, TRUE)`.
#' @param series One series (index or name) or two series for the cross
#'   spectrum.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vspectrum` with fields `call`, `series`
#'   and `table`, a data.frame with column `freq` (radians, from 0 to pi) and
#'   * one series: `periodogram` and `spectrum` (smoothed),
#'   * two series: `cross_amplitude` (modulus of the smoothed cross
#'     spectrum), `spectrum1`, `spectrum2` (smoothed), `gain12` (cross
#'     amplitude over the spectrum of the first series), `gain21` and
#'     `coherence` (squared coherence).
#' @examples
#' plot(vspectrum(vdif(log(airpas)), smooth = 5))
#' plot(vspectrum(vdif(log(lydia_pinkham)), smooth = 7, series = c(1, 2)))
#' @export
vspectrum <- function(y, smooth = 1, xlog = c(FALSE, TRUE), series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  smooth <- max(1, min(floor(n / 2), tsx_check_int(smooth, "smooth")))
  if (smooth %% 2 == 0) smooth <- smooth + 1
  idx <- tsx_series_index(series, y)
  if (length(idx) > 2) idx <- idx[1:2]
  sp <- tsx_mspectrum(y[, idx, drop = FALSE])
  w <- sp$w
  if (length(idx) == 1 || idx[1] == idx[2]) {
    per <- Re(sp$i[1, 1, ])
    tab <- data.frame(freq = w, periodogram = per,
                      spectrum = Re(tsx_smooth_triangular(per, smooth, n %% 2 == 0)))
    idx <- idx[1]
  } else {
    sm <- lapply(list(sp$i[1, 2, ], sp$i[1, 1, ], sp$i[2, 2, ]), tsx_smooth_triangular,
                 smooth = smooth, even = n %% 2 == 0)
    a <- Mod(sm[[1]])
    s1 <- Re(sm[[2]])
    s2 <- Re(sm[[3]])
    tab <- data.frame(freq = w, cross_amplitude = a, spectrum1 = s1, spectrum2 = s2,
                      gain12 = a / s1, gain21 = a / s2, coherence = a^2 / (s1 * s2))
  }
  tsx_result("vspectrum", call = list(smooth = smooth, xlog = as.logical(rep_len(xlog, 2)),
                                      series = idx),
             series = colnames(y)[idx], table = tab)
}

# Periodogram matrices I[, , j] = conj(F_j) F_j' / (2 pi T) at
# the Fourier frequencies w_j = 2 pi j / T, j = 0, ..., floor(T / 2).
# Missing values are skipped in the discrete Fourier transform.
tsx_mspectrum <- function(z) {
  z <- as.matrix(z)
  n <- nrow(z)
  m <- ncol(z)
  nw <- floor(n / 2) + 1
  w <- 2 * pi * (0:(nw - 1)) / n
  tt <- seq_len(n)
  f <- matrix(0 + 0i, m, nw)
  for (k in seq_len(m)) {
    ok <- !is.na(z[, k])
    for (j in seq_len(nw)) f[k, j] <- sum(z[ok, k] * exp(-1i * w[j] * (tt[ok] - 1)))
  }
  out <- array(0 + 0i, c(m, m, nw))
  for (j in seq_len(nw)) out[, , j] <- Conj(f[, j]) %*% t(f[, j])
  for (k in seq_len(m)) out[k, k, ] <- Re(out[k, k, ])
  list(i = out / (2 * pi * n), w = w)
}

# Triangular smoothing: centred moving average with
# weights 1, 2, ..., (L + 1) / 2, ..., 2, 1 (normalised). x holds the
# (cross) periodogram at the frequencies 2 pi j / T, j = 0, ..., floor(T/2).
# At both ends the periodogram is extended by symmetry, I(-w) = conj(I(w))
# and I(pi + w) = conj(I(pi - w)). 'even' indicates whether T is
# even (the last frequency is then pi).
tsx_smooth_triangular <- function(x, smooth, even = TRUE) {
  if (smooth <= 1) return(x)
  if (smooth %% 2 == 0) smooth <- smooth + 1
  inc <- 2 / (smooth + 1)
  b <- c(seq(inc, 1 - inc / 2, by = inc), 1, rev(seq(inc, 1 - inc / 2, by = inc)))
  b <- b / sum(b)
  lb <- (length(b) - 1) / 2
  n <- length(x)
  if (lb > n - 2) stop("The smoothing window is too long for the sample size.", call. = FALSE)
  left <- Conj(rev(x[2:(lb + 1)]))
  right <- if (even) Conj(x[(n - 1):(n - lb)]) else Conj(x[n:(n - lb + 1)])
  xp <- c(left, x, right)
  out <- x
  for (k in seq_len(n)) out[k] <- sum(b * rev(xp[k:(k + 2 * lb)]))
  out
}

#' @export
print.tsx_vspectrum <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  title <- if (length(x$series) == 1) {
    paste0("Series ", x$series, ": ",
           if (x$call$smooth > 1) paste0("Smoothed Spectrum, Triangular window (", x$call$smooth, ")")
           else "Periodogram")
  } else {
    paste0("Cross spectrum: ", x$series[1], " - ", x$series[2])
  }
  tsx_cat_block(title = title, table = tsx_format_table(x$table, digits))
  invisible(x)
}

#' @export
plot.tsx_vspectrum <- function(x, ...) {
  t <- x$table
  xlog <- x$call$xlog
  fx <- tsx_period_axis(t$freq, xlog[1])
  if (length(x$series) == 1) {
    yv <- if (xlog[2]) log10(t$spectrum) else t$spectrum
    title <- paste0("Series ", x$series, ": ",
                    if (x$call$smooth > 1) paste0("Smoothed Spectrum, Triangular window (",
                                                  x$call$smooth, ")") else "Periodogram")
    graphics::plot(fx$x, yv, type = "l", xaxt = "n", xlim = fx$lim,
                   xlab = fx$lab, ylab = if (xlog[2]) "Log10(Power)" else "Power", main = title)
    fx$axis()
  } else {
    op <- graphics::par(mfrow = c(2, 1), mar = c(4, 4, 3, 4))
    on.exit(graphics::par(op))
    g1 <- if (xlog[2]) log10(t$gain12) else t$gain12
    g2 <- if (xlog[2]) log10(t$gain21) else t$gain21
    ylab <- if (xlog[2]) "log(Gains)" else "Gains"
    graphics::plot(fx$x, g1, type = "l", xaxt = "n", xlim = fx$lim, xlab = "", ylab = ylab,
                   main = paste0("Gains: ", x$series[2], " <- ", x$series[1],
                                 " (left - black) and ", x$series[1], " <- ", x$series[2],
                                 " (right - red)"), cex.main = 0.85)
    fx$axis()
    graphics::par(new = TRUE)
    graphics::plot(fx$x, g2, type = "l", col = "red", axes = FALSE, xlab = "", ylab = "",
                   xlim = fx$lim)
    graphics::axis(4, col.axis = "red")
    graphics::plot(fx$x, t$coherence, type = "l", xaxt = "n", xlim = fx$lim, ylim = c(0, 1.1),
                   xlab = fx$lab, ylab = "Coherence",
                   main = paste0("Squared Coherence: ", x$series[1], " - ", x$series[2],
                                 if (x$call$smooth > 1) paste0(". Smoothed Spectrum, Triangular window (",
                                                               x$call$smooth, ")")),
                   cex.main = 0.85)
    fx$axis()
  }
  invisible(x)
}

# Frequency axis labelled with periods.
tsx_period_axis <- function(w, logx) {
  periods <- c(12, 6, 4, 3, 2.4, 2)
  if (!logx) {
    list(x = w, lim = c(0, pi), lab = "Period",
         axis = function() graphics::axis(1, at = c(0, 2 * pi / periods),
                                          labels = c("Inf", periods)))
  } else {
    lw <- log10(w)
    lw[w == 0] <- NA
    lo <- min(lw, na.rm = TRUE)
    list(x = lw, lim = c(lo, log10(pi)), lab = "Log10(Period)",
         axis = function() graphics::axis(1, at = log10(2 * pi / periods), labels = periods))
  }
}

#' Autoregressive spectrum
#'
#' Spectrum of an AR model of order `order` (with constant) fitted by least
#' squares to one series,
#' \eqn{f(\omega) = \sigma^2 / (2\pi) |1 / \phi(e^{-i\omega})|^2}, in the same
#' scale as the periodogram of [vspectrum()].
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param order Order of the AR model. Default 16 (limited to `T / 2`).
#' @param nfreq Number of frequencies in `[0, pi)`. `0` or `NULL` uses the
#'   Fourier frequencies `2 pi j / T`; values below 10 are replaced by
#'   `floor(T / 2)`. Default `floor(T / 2)`.
#' @inheritParams vspectrum
#' @param series Series to analyse (index or name).
#' @return An object of class `tsx_varspectrum` with fields `call`, `series`,
#'   `ar` (estimated AR coefficients), `sigma2` (innovation variance) and
#'   `table` (data.frame with columns
#'   `freq`, radians, and `spectrum`).
#' @examples
#' plot(varspectrum(vdif(log(airpas)), order = 14))
#' @export
varspectrum <- function(y, order = 16, nfreq = NULL, xlog = c(FALSE, TRUE), series = 1,
                        names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  t2 <- floor(n / 2)
  if (is.null(nfreq)) nfreq <- t2
  if (nfreq == 0) {
    freq <- 2 * pi * (0:t2) / n
  } else {
    if (nfreq < 10) nfreq <- t2
    freq <- seq(0, pi - pi / nfreq, by = pi / nfreq)
  }
  order <- max(1, min(t2, tsx_check_int(order, "order")))
  i <- tsx_series_index(series, y)[1]
  v <- tsx_mvar(y[, i, drop = FALSE], seq_len(order), const = TRUE)
  ar <- as.vector(v$p[seq_len(order), 1])
  h <- vapply(freq, function(w) {
    1 / Mod(1 - sum(ar * exp(-1i * w * seq_len(order))))^2
  }, numeric(1))
  tsx_result("varspectrum", call = list(order = order, nfreq = nfreq,
                                        xlog = as.logical(rep_len(xlog, 2)), series = i),
             series = colnames(y)[i], ar = ar, sigma2 = v$sigma[1, 1],
             table = data.frame(freq = freq, spectrum = v$sigma[1, 1] / (2 * pi) * h))
}

#' @export
print.tsx_varspectrum <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(title = paste0("Series ", x$series, ": AR Spectrum(", x$call$order, ")"),
                table = tsx_format_table(x$table, digits, col_names = c("Frequency", "Power")))
  invisible(x)
}

#' @export
plot.tsx_varspectrum <- function(x, ...) {
  t <- x$table
  xlog <- x$call$xlog
  fx <- tsx_period_axis(t$freq, xlog[1])
  yv <- if (xlog[2]) log10(t$spectrum) else t$spectrum
  graphics::plot(fx$x, yv, type = "l", xaxt = "n", xlim = fx$lim, xlab = fx$lab,
                 ylab = if (xlog[2]) "Log10(Power)" else "Power",
                 main = paste0("Series ", x$series, ": AR Spectrum(", x$call$order, ")"))
  fx$axis()
  invisible(x)
}
