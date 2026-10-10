# Forecast evaluation tools: faccuracy(), fcompare() and fplot().
#
# Layout of the inputs:
#   y      T x m matrix of actual values.
#   py     forecasts, n * m columns: forecast f of series s is column
#          (f - 1) * m + s.
#   stdpy  standard deviations of the forecasts, n * m columns with the
#          layout of py.
# The bands are py -/+ z * stdpy, with z the (1 + level) / 2 quantile of the
# standard normal distribution; internally they are kept in a matrix with
# 2 * n * m columns: lower band of forecast f of series s in column
# (f - 1) * 2 * m + s and the upper band in (f - 1) * 2 * m + m + s.
# y and py must be of the same type: both without dates (aligned by
# position), both ts (aligned on their common time grid) or both zoo, xts or
# data.frame with a date column (aligned by their dates).

# Alignment of actual values, forecasts and standard deviations. Returns y,
# py, stdpy (matrices with the same number of rows), bands (NULL without
# stdpy), origin, nf (number of forecasts) and dates (date of each row, or
# NULL when the inputs have no dates).
tsx_forecast_align <- function(y, py, stdpy = NULL, origin = 0, names = NULL, level = 0.95) {
  tsx_check_level(level)
  a <- tsx_forecast_align_inputs(y, py, stdpy, origin, names)
  a$bands <- tsx_forecast_bands(a$py, a$stdpy, ncol(a$y), level)
  a
}

# Bands py -/+ z * stdpy, z = qnorm((1 + level) / 2), in the internal layout
# (2 * n * m columns, see the top of this file).
tsx_forecast_bands <- function(py, stdpy, m, level) {
  if (is.null(stdpy)) return(NULL)
  z <- stats::qnorm((1 + level) / 2)
  bands <- matrix(NA_real_, nrow(py), 2 * ncol(py))
  for (f in seq_len(ncol(py) / m)) {
    pc <- (f - 1) * m + seq_len(m)
    lc <- (f - 1) * 2 * m + seq_len(m)
    bands[, lc] <- py[, pc] - z * stdpy[, pc]
    bands[, lc + m] <- py[, pc] + z * stdpy[, pc]
  }
  bands
}

tsx_forecast_align_inputs <- function(y, py, stdpy, origin, names) {
  type_y <- tsx_input_parts(y)$type
  type_p <- tsx_input_parts(py)$type
  if (type_y != type_p) {
    stop("'y' and 'py' must be of the same type (", tsx_type_label(type_y), " and ",
         tsx_type_label(type_p), " given).", call. = FALSE)
  }
  if (!is.null(stdpy)) {
    type_s <- tsx_input_parts(stdpy)$type
    if (!type_s %in% c(type_p, "undated")) {
      stop("'stdpy' must be of the same type as 'py' or have no dates (",
           tsx_type_label(type_s), " given).", call. = FALSE)
    }
  }
  if (type_y == "undated") return(tsx_forecast_align_rows(y, py, stdpy, origin, names))
  if (type_y == "ts") return(tsx_forecast_align_ts(y, py, stdpy, origin, names))
  tsx_forecast_align_index(y, py, stdpy, origin, names)
}

# Description of an input type for the error messages.
tsx_type_label <- function(type) {
  switch(type, undated = "data without dates", ts = "a ts object", xts = "an xts object",
         zoo = "a zoo object", data.frame = "a data.frame with dates",
         dated = "a dated matrix", type)
}

# Numeric matrix of the values of an input object (without its dates).
tsx_values_matrix <- function(x) {
  v <- tsx_input_parts(x)$values
  if (is.data.frame(v) && !all(vapply(v, is.numeric, logical(1)))) {
    stop("All the columns of the forecasts and their standard deviations must be numeric.", call. = FALSE)
  }
  v <- as.matrix(v)
  storage.mode(v) <- "double"
  attr(v, "dates") <- NULL
  v
}

# Standard deviations of the forecasts: mh columns, the layout of py
# (missing ones filled with NA).
tsx_sd_cols <- function(sm, mh) {
  if (ncol(sm) > mh) {
    stop("'stdpy' must have at most as many columns as 'py' (the standard deviations ",
         "of the forecasts), not ", ncol(sm), ".", call. = FALSE)
  }
  if (any(sm < 0, na.rm = TRUE)) {
    stop("'stdpy' must contain standard deviations (non negative values).", call. = FALSE)
  }
  if (ncol(sm) < mh) sm <- cbind(sm, matrix(NA_real_, nrow(sm), mh - ncol(sm)))
  sm
}

tsx_check_py_cols <- function(mh, m) {
  if (mh %% m != 0) {
    stop("The number of columns of 'py' must be a multiple of the number of series.",
         call. = FALSE)
  }
}

# Alignment by position of data without dates: series of different lengths
# are aligned at the end (padding with missing values at the beginning);
# when y is longer than py the forecast origin is T - nrow(py).
tsx_forecast_align_rows <- function(y, py, stdpy, origin, names) {
  y <- as_tsx_matrix(y, names, trim = FALSE)
  py <- tsx_values_matrix(py)
  n <- nrow(y)
  m <- ncol(y)
  nh <- nrow(py)
  mh <- ncol(py)
  tsx_check_py_cols(mh, m)
  if (!is.null(stdpy)) stdpy <- tsx_sd_cols(tsx_values_matrix(stdpy), mh)
  if (is.null(origin)) origin <- 0
  if (nh > n) y <- rbind(y, matrix(NA_real_, nh - n, m, dimnames = list(NULL, colnames(y))))
  n <- nrow(y)
  pp <- max(nrow(stdpy), nh, n)
  pad <- function(x) {
    if (is.null(x) || nrow(x) == pp) return(x)
    rbind(matrix(NA_real_, pp - nrow(x), ncol(x), dimnames = list(NULL, colnames(x))), x)
  }
  if (n > nh) origin <- n - nh
  y <- pad(y)
  py <- pad(py)
  stdpy <- pad(stdpy)
  list(y = y, py = py, stdpy = stdpy, origin = origin, nf = mh / m, dates = NULL)
}

# Alignment of ts objects. The common grid goes from the earliest start to
# the latest end of y, py and stdpy (all with the same frequency); every
# input is placed at the rows of its dates, with missing values elsewhere.
# stdpy may be a ts object or a matrix with the rows of py. When 'origin' is
# 0 it is set to the number of periods before the start of py.
tsx_forecast_align_ts <- function(y, py, stdpy, origin, names) {
  freq <- stats::frequency(y)
  same_freq <- function(x) isTRUE(all.equal(stats::frequency(x), freq))
  if (!same_freq(py)) stop("'y' and 'py' must have the same frequency.", call. = FALSE)
  std_ts <- !is.null(stdpy) && stats::is.ts(stdpy)
  if (std_ts && !same_freq(stdpy)) {
    stop("'y' and 'stdpy' must have the same frequency.", call. = FALSE)
  }
  tsps <- list(stats::tsp(y), stats::tsp(py))
  if (std_ts) tsps <- c(tsps, list(stats::tsp(stdpy)))
  t0 <- min(vapply(tsps, `[`, 0, 1))
  t1 <- max(vapply(tsps, `[`, 0, 2))
  # row (0-based) of a date in the grid; dates must fall on the grid
  offset <- function(time) {
    k <- (time - t0) * freq
    if (abs(k - round(k)) > 1e-6) {
      stop("The dates of 'y', 'py' and 'stdpy' are not on the same time grid.", call. = FALSE)
    }
    as.integer(round(k))
  }
  nrows <- offset(t1) + 1L
  place <- function(x, start) {
    out <- matrix(NA_real_, nrows, ncol(x), dimnames = list(NULL, colnames(x)))
    out[start + seq_len(nrow(x)), ] <- x
    out
  }
  yy <- as_tsx_matrix(y, names, trim = FALSE)
  pm <- tsx_values_matrix(py)
  m <- ncol(yy)
  mh <- ncol(pm)
  tsx_check_py_cols(mh, m)
  py_start <- offset(stats::tsp(py)[1])
  yy <- place(yy, offset(stats::tsp(y)[1]))
  pm <- place(pm, py_start)
  if (!is.null(stdpy)) {
    sm <- tsx_values_matrix(stdpy)
    if (std_ts) {
      s_start <- offset(stats::tsp(stdpy)[1])
    } else if (nrow(sm) == nrow(as.matrix(py))) {
      s_start <- py_start
    } else {
      stop("'stdpy' must be a ts object or have the same number of rows as 'py'.",
           call. = FALSE)
    }
    stdpy <- place(tsx_sd_cols(sm, mh), s_start)
  }
  if (is.null(origin) || origin == 0) origin <- py_start
  list(y = yy, py = pm, stdpy = stdpy, origin = origin, nf = mh / m,
       dates = tsx_ts_dates(t0 + (seq_len(nrows) - 1) / freq, freq))
}

# Alignment by dates of zoo, xts and data.frame objects: the rows are the
# union of the dates of y, py and stdpy (which must be of the same kind:
# Date, POSIXct or numeric); every input is placed at the rows of its dates,
# with missing values elsewhere. stdpy may be dated or a matrix with the rows
# of py. When 'origin' is 0 it is set to the number of dates before the
# first date of py.
tsx_forecast_align_index <- function(y, py, stdpy, origin, names) {
  yy <- as_tsx_matrix(y, names, trim = FALSE)
  dy <- attr(yy, "dates")
  dp <- tsx_input_parts(py)$dates
  pm <- tsx_values_matrix(py)
  if (tsx_date_kind(dy) != tsx_date_kind(dp)) {
    stop("The dates of 'y' and 'py' are of different kinds (", tsx_date_kind(dy), " and ",
         tsx_date_kind(dp), ").", call. = FALSE)
  }
  if (length(dp) != nrow(pm)) {
    stop("The number of dates and of rows of 'py' differ.", call. = FALSE)
  }
  m <- ncol(yy)
  mh <- ncol(pm)
  tsx_check_py_cols(mh, m)
  ds <- NULL
  if (!is.null(stdpy)) {
    sm <- tsx_values_matrix(stdpy)
    ds <- tsx_input_parts(stdpy)$dates
    if (is.null(ds)) {
      if (nrow(sm) != nrow(pm)) {
        stop("'stdpy' must have dates or the same number of rows as 'py'.", call. = FALSE)
      }
      ds <- dp
    } else if (tsx_date_kind(ds) != tsx_date_kind(dp)) {
      stop("The dates of 'py' and 'stdpy' are of different kinds.", call. = FALSE)
    }
  }
  all <- sort(unique(c(dy, dp, ds)))
  key <- as.numeric(all)
  place <- function(x, d) {
    out <- matrix(NA_real_, length(all), ncol(x), dimnames = list(NULL, colnames(x)))
    out[match(as.numeric(d), key), ] <- x
    out
  }
  yy <- place(yy, dy)
  pm2 <- place(pm, dp)
  if (!is.null(stdpy)) stdpy <- place(tsx_sd_cols(sm, mh), ds)
  if (is.null(origin) || origin == 0) origin <- sum(key < as.numeric(dp[1]))
  list(y = yy, py = pm2, stdpy = stdpy, origin = origin, nf = mh / m, dates = all)
}

# Columns of the forecasts and bands of one series.
tsx_forecast_cols <- function(series, m, nf) {
  f <- seq_len(nf)
  list(py = (f - 1) * m + series,
       lower = (f - 1) * 2 * m + series,
       upper = (f - 1) * 2 * m + m + series)
}

# Error when no period after the origin has both an actual value and a
# forecast of the series (actual values and forecasts do not overlap). The
# condition has class "tsx_no_overlap" so that the GUI can show the plot
# without tables.
tsx_check_overlap <- function(actual, fc) {
  both <- !is.na(actual) & rowSums(!is.na(as.matrix(fc))) > 0
  if (!any(both)) {
    stop(structure(class = c("tsx_no_overlap", "error", "condition"),
                   list(message = paste("The actual values and the forecasts do not overlap:",
                                        "no accuracy measures can be computed."),
                        call = NULL)))
  }
  invisible()
}

# Check the confidence level of the prediction intervals.
tsx_check_level <- function(level) {
  if (!is.numeric(level) || length(level) != 1 || is.na(level) || level <= 0 || level >= 1) {
    stop("'level' must be a number between 0 and 1.", call. = FALSE)
  }
  invisible(level)
}

# Forecasting period of the tables ("Forecasting period: first to last").
tsx_period_text <- function(dates) {
  if (is.null(dates) || length(dates) == 0) return(NULL)
  d <- tsx_format_dates(dates)
  paste0("Forecasting period: ", d[1], " to ", d[length(d)])
}

# Cumulative sum skipping missing values (kept as NA).
tsx_nancumsum <- function(x) {
  out <- rep(NA_real_, length(x))
  ok <- !is.na(x)
  out[ok] <- cumsum(x[ok])
  out
}

#' Forecast accuracy measures
#'
#' Error measures of one or several forecasts of one series over the
#' forecasting period (observations after `origin`), and measures of the
#' uncertainty of their prediction intervals when `stdpy` is given.
#'
#' Point forecast measures, with \eqn{e_t = F_t - y_t}:
#' * Bias and MAE: mean error and mean absolute error.
#' * Bias+MAE: \eqn{|Bias| + MAE}.
#' * RMSE: root mean squared error.
#' * MASE: MAE relative to the in-sample MAE of the one step naive forecast
#'   (only when `origin > 0`).
#'
#' Interval measures (only with `stdpy`), with \eqn{\alpha = 1 - } `level`
#' and the bounds of the Gaussian prediction intervals
#' \eqn{l_t = F_t - z \sigma_t} and \eqn{u_t = F_t + z \sigma_t}, being
#' \eqn{\sigma_t} the standard deviation of the forecast (`stdpy`) and
#' \eqn{z} the \eqn{1 - \alpha / 2} quantile of the standard normal
#' distribution (1.96 for `level = 0.95`):
#' * Coverage: proportion of actual values inside \eqn{[l_t, u_t]} (to be
#'   compared with `level`).
#' * Range: mean width \eqn{u_t - l_t}.
#' * MIS (mean interval score): mean of \eqn{(u_t - l_t) + \frac{2}{\alpha}
#'   (l_t - y_t) 1(y_t < l_t) + \frac{2}{\alpha} (y_t - u_t) 1(y_t > u_t)}.
#' * Pinball loss of the lower bound (quantile \eqn{\tau = \alpha / 2}) and
#'   of the upper bound (\eqn{\tau = 1 - \alpha / 2}): mean of
#'   \eqn{\tau (y_t - q_t)} if \eqn{y_t \ge q_t} and
#'   \eqn{(1 - \tau) (q_t - y_t)} otherwise.
#'
#' If no period after `origin` has both an actual value and a forecast (the
#' forecasts do not overlap the actual values), an error of class
#' `tsx_no_overlap` is raised. The same applies to [fcompare()]; [fplot()]
#' plots these data without problems.
#'
#' @param y Actual values (see [as_tsx_matrix()]); it may include the
#'   in-sample period.
#' @param py Forecasts: a matrix with `n * m` columns, being `m` the number of
#'   series in `y` and `n` the number of forecasts; forecast `f` of series `s`
#'   is in column `(f - 1) * m + s`. `y` and `py` must be of the same type
#'   (an error is raised otherwise): both without dates (vectors, matrices or
#'   numeric `data.frame`s; aligned at the end), both `ts` with the same
#'   frequency (aligned on their common time grid), or both `zoo`, both `xts`
#'   or both `data.frame` with a date column (aligned by their dates, which
#'   must be of the same class). See [as_tsx_matrix()] for the dated inputs.
#' @param stdpy Optional standard deviations of the forecasts, with the
#'   layout of `py` (the standard deviation of forecast `f` of series `s` is
#'   in column `(f - 1) * m + s`; missing columns at the end are taken as
#'   not available). The prediction intervals are `py -/+ z * stdpy`, with
#'   `z = qnorm((1 + level) / 2)`. With dated inputs it may be of the same
#'   type as `py` or have no dates and the rows of `py`.
#' @param origin Forecast origin: number of in-sample observations. If `y` is
#'   longer than `py`, it is set to `nrow(y) - nrow(py)`. With dated inputs
#'   and `origin = 0`, it is the number of periods before the first date of
#'   `py` (counted from the earliest date of `y` and `py`).
#' @param series Series to evaluate (index or name).
#' @param level Confidence level of the prediction intervals computed from
#'   `stdpy` (default 0.95); the significance level is
#'   \eqn{\alpha = 1 - } `level`.
#' @param names Optional names of the series.
#' @return An object of class `tsx_faccuracy` with fields `call`, `series`,
#'   `table` (data.frame, one row per forecast, with columns `forecast`, `n`,
#'   `bias`, `mae`, `bias_mae`, `rmse`, `mase`, `coverage`, `range`, `mis`,
#'   `pinball_lower` and `pinball_upper`; the interval measures are `NA`
#'   without `stdpy`) and `by_horizon` (data.frame with the same measures
#'   accumulated up to each period of the forecasting sample, with columns
#'   `forecast`, `t`, `date` (only for dated inputs), `actual`, `fcst`, `e`
#'   and the measures) and `dates` (dates of the forecasting sample for dated
#'   inputs, otherwise `NULL`).
#' @references
#' Hyndman, R.J. and Koehler, A.B. (2006). Another look at measures of
#' forecast accuracy. *International Journal of Forecasting*, 22, 679-688.
#'
#' Gneiting, T. and Raftery, A.E. (2007). Strictly proper scoring rules,
#' prediction, and estimation. *Journal of the American Statistical
#' Association*, 102, 359-378.
#'
#' Svetunkov, I. (2023). *Forecasting and Analytics with the Augmented
#' Dynamic Adaptive Model (ADAM)*. Chapman and Hall/CRC.
#' <https://openforecast.org/adam/>
#' @examples
#' # data without dates (forecasts aligned with the end of y)
#' y <- as.vector(log(airpas))
#' f1 <- y[121:132]          # naive seasonal forecast
#' f2 <- rep(y[132], 12)     # naive forecast
#' faccuracy(y, cbind(f1, f2))
#' # with 95% intervals of the first forecast (standard deviation 0.05)
#' faccuracy(y, f1, rep(0.05, 12))
#' # data with dates (both of the same type), aligned by their dates
#' d <- seq(as.Date("1949-01-01"), by = "month", length.out = 144)
#' yd <- data.frame(date = d, y = y)
#' fd <- data.frame(date = d[133:144], f1 = f1, f2 = f2)
#' faccuracy(yd, fd)
#' @export
faccuracy <- function(y, py, stdpy = NULL, origin = 0, series = 1, level = 0.95,
                      names = NULL) {
  tsx_check_level(level)
  alpha <- 1 - level
  a <- tsx_forecast_align(y, py, stdpy, origin, names, level)
  yy <- a$y
  n <- nrow(yy)
  m <- ncol(yy)
  origin <- a$origin
  s <- tsx_series_index(series, yy)[1]
  cc <- tsx_forecast_cols(s, m, a$nf)
  cols <- cc$py
  if (origin >= n) tsx_check_overlap(NA, NA)
  tt <- (origin + 1):n
  actual <- yy[tt, s]
  tsx_check_overlap(actual, a$py[tt, cols, drop = FALSE])
  zin <- if (origin > 0) yy[seq_len(origin), s] else NULL
  maseden <- if (!is.null(zin)) mean(abs(diff(zin)), na.rm = TRUE) else NA_real_
  ind <- !is.na(actual)
  tindx <- sum(ind)
  ti <- if (any(ind)) cumsum(ind) else rep(1, length(ind))
  na_h <- rep(NA_real_, length(tt))
  # mean and cumulative mean over the non missing values of x
  mean_ok <- function(x) if (any(!is.na(x))) mean(x, na.rm = TRUE) else NA_real_
  cummean_ok <- function(x) {
    k <- cumsum(!is.na(x))
    out <- tsx_nancumsum(x) / k
    out[k == 0] <- NA_real_
    out
  }
  pinball <- function(q, tau) ifelse(actual >= q, tau * (actual - q), (1 - tau) * (q - actual))
  tab <- NULL
  hor <- NULL
  for (f in seq_along(cols)) {
    fc <- a$py[tt, cols[f]]
    e <- fc - actual
    # interval measures
    cover <- width <- score <- pb_l <- pb_u <- na_h
    if (!is.null(a$bands)) {
      lo <- a$bands[tt, cc$lower[f]]
      up <- a$bands[tt, cc$upper[f]]
      okb <- !is.na(actual) & !is.na(lo) & !is.na(up)
      lo[!okb] <- NA_real_
      up[!okb] <- NA_real_
      cover <- as.numeric(actual >= lo & actual <= up)
      width <- up - lo
      score <- width + 2 / alpha * (lo - actual) * (actual < lo) +
        2 / alpha * (actual - up) * (actual > up)
      pb_l <- pinball(lo, alpha / 2)
      pb_u <- pinball(up, 1 - alpha / 2)
    }
    bias <- sum(e, na.rm = TRUE) / tindx
    mae <- sum(abs(e), na.rm = TRUE) / tindx
    bias_h <- tsx_nancumsum(e) / ti
    mae_h <- tsx_nancumsum(abs(e)) / ti
    tab <- rbind(tab, data.frame(
      forecast = f, n = tindx,
      bias = bias, mae = mae, bias_mae = abs(bias) + mae,
      rmse = sqrt(sum(e^2, na.rm = TRUE) / tindx),
      mase = if (is.null(zin)) NA_real_ else sum(abs(e) / maseden, na.rm = TRUE) / tindx,
      coverage = mean_ok(cover), range = mean_ok(width), mis = mean_ok(score),
      pinball_lower = mean_ok(pb_l), pinball_upper = mean_ok(pb_u)))
    hor <- rbind(hor, data.frame(
      forecast = f, t = tt, actual = actual, fcst = fc, e = e,
      bias = bias_h, mae = mae_h, bias_mae = abs(bias_h) + mae_h,
      rmse = sqrt(tsx_nancumsum(e^2) / ti),
      mase = if (is.null(zin)) na_h else tsx_nancumsum(abs(e) / maseden) / ti,
      coverage = cummean_ok(cover), range = cummean_ok(width), mis = cummean_ok(score),
      pinball_lower = cummean_ok(pb_l), pinball_upper = cummean_ok(pb_u)))
  }
  rownames(tab) <- rownames(hor) <- NULL
  if (!is.null(a$dates)) hor <- data.frame(hor[1:2], date = a$dates[hor$t], hor[-(1:2)])
  tsx_result("faccuracy", call = list(origin = origin, series = s, level = level),
             series = colnames(yy)[s], table = tab, by_horizon = hor,
             dates = if (is.null(a$dates)) NULL else a$dates[tt])
}

#' @export
print.tsx_faccuracy <- function(x, digits = 3, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  t <- x$table
  keep <- vapply(t, function(v) !all(is.na(v)), logical(1))
  t <- t[, keep, drop = FALSE]
  lv <- if (is.null(x$call$level)) 0.95 else x$call$level
  notes <- c(bias = "bias:          Mean Error (F - y)",
             mae = "mae:           Mean Absolute Error",
             bias_mae = "bias+mae:      |bias| + mae",
             rmse = "rmse:          Root Mean Squared Error",
             mase = "mase:          Mean Absolute Scaled Error (mae out sample / mae in sample)",
             coverage = paste0("coverage:      proportion of actual values inside the intervals",
                               " (nominal ", format(lv), ")"),
             range = "range:         mean width of the intervals",
             mis = paste0("mis:           Mean Interval Score (alpha = ", format(1 - lv), ")"),
             pinball_lower = "pinball_lower: pinball loss of the lower bound (quantile alpha / 2)",
             pinball_upper = "pinball_upper: pinball loss of the upper bound (quantile 1 - alpha / 2)")
  cols <- setdiff(names(t), "forecast")
  tsx_cat_block(title = c("Forecasting Results", paste("Series", x$series),
                          tsx_period_text(x$dates)),
                notes = notes[intersect(names(notes), cols)],
                table = tsx_format_table(t[, cols, drop = FALSE],
                                         c(0, rep(digits, length(cols) - 1)),
                                         row_names = paste0("F#", t$forecast),
                                         col_names = sub("^bias_mae$", "bias+mae", cols)))
  invisible(x)
}

#' Forecast comparison tests
#'
#' For every pair of forecasts of one series, tests of the null hypothesis of
#' equal accuracy based on squared errors (MSE) and on absolute errors (MAE):
#' Diebold-Mariano (with `trunc` autocovariances in
#' the long run variance of the loss differential), sign test and Wilcoxon
#' signed rank test (exact for up to 15 non-zero differences, normal
#' approximation without continuity correction otherwise). An error of class
#' `tsx_no_overlap` is raised when the actual values and the forecasts do not
#' overlap (see [faccuracy()]).
#'
#' @inheritParams faccuracy
#' @param trunc Truncation lag of the long run variance of the
#'   Diebold-Mariano test (number of autocovariances). Default 1.
#' @return An object of class `tsx_fcompare` with fields `call`, `series`,
#'   `dates` (dates of the forecasting sample for dated inputs, otherwise
#'   `NULL`) and `table`, a data.frame with one row per pair of forecasts and loss
#'   function: `f1`, `f2`, `loss` (`"mse"` or `"mae"`), `dm`, `p_dm`,
#'   `sign`, `p_sign`, `wilcoxon` (sum of the ranks of the positive
#'   differences) and `p_wilcoxon`.
#' @references
#' Diebold, F.X. and Mariano, R.S. (1995). Comparing predictive accuracy.
#' *Journal of Business and Economic Statistics*, 13, 253-263.
#'
#' Wilcoxon, F. (1945). Individual comparisons by ranking methods.
#' *Biometrics Bulletin*, 1, 80-83.
#' @examples
#' y <- as.vector(log(airpas))
#' fcompare(y, cbind(y[121:132], rep(y[132], 12)))
#' @export
fcompare <- function(y, py, origin = 0, trunc = 1, series = 1, names = NULL) {
  a <- tsx_forecast_align(y, py, NULL, origin, names)
  yy <- a$y
  n <- nrow(yy)
  m <- ncol(yy)
  origin <- a$origin
  s <- tsx_series_index(series, yy)[1]
  cols <- tsx_forecast_cols(s, m, a$nf)$py
  nf <- length(cols)
  if (nf < 2) stop("At least two forecasts are needed.", call. = FALSE)
  if (origin >= n) tsx_check_overlap(NA, NA)
  tt <- (origin + 1):n
  nofs <- n - origin
  trunc <- min(tsx_check_int(trunc, "trunc", 0), nofs - 1)
  actual <- yy[tt, s]
  tsx_check_overlap(actual, a$py[tt, cols, drop = FALSE])
  e <- a$py[tt, cols, drop = FALSE] - actual
  tab <- tsx_compare_losses(list(mse = e^2, mae = abs(e)), trunc, nofs)
  tsx_result("fcompare", call = list(origin = origin, trunc = trunc, series = s),
             series = colnames(yy)[s], table = tab,
             dates = if (is.null(a$dates)) NULL else a$dates[tt])
}

# Diebold-Mariano, sign and Wilcoxon tests for every pair of forecasts and
# every loss: 'loss' is a named list of matrices (periods x forecasts).
tsx_compare_losses <- function(loss, trunc, nofs) {
  nf <- ncol(loss[[1]])
  tab <- NULL
  for (i in seq_len(nf - 1)) {
    for (j in (i + 1):nf) {
      for (l in names(loss)) {
        li <- loss[[l]][, i]
        lj <- loss[[l]][, j]
        dm <- tsx_dm_test(li - lj, trunc, nofs)
        sg <- tsx_sign_test(li - lj, nofs)
        wi <- tsx_signrank(li, lj)
        tab <- rbind(tab, data.frame(f1 = i, f2 = j, loss = l, dm = dm[1], p_dm = dm[2],
                                     sign = sg[1], p_sign = sg[2], wilcoxon = wi[1],
                                     p_wilcoxon = wi[2], stringsAsFactors = FALSE))
      }
    }
  }
  rownames(tab) <- NULL
  tab
}

# Diebold-Mariano statistic and two sided p-value.
tsx_dm_test <- function(d, trunc, nofs) {
  dt <- d - mean(d, na.rm = TRUE)
  m1 <- mean(d, na.rm = TRUE)
  f0 <- stats::var(dt, na.rm = TRUE)
  nd <- length(dt)
  for (k in seq_len(trunc)) {
    f0 <- f0 + 2 * sum(dt[(k + 1):nd] * dt[1:(nd - k)], na.rm = TRUE) / nofs
  }
  if (is.na(f0)) return(c(NA_real_, NA_real_))
  if (f0 >= 0) {
    stat <- if (f0 > 0) m1 / sqrt(f0 / nofs) else 0
    c(stat, 2 * stats::pnorm(abs(stat), lower.tail = FALSE))
  } else {
    c(Inf, 0)
  }
}

# Sign test (normal approximation).
tsx_sign_test <- function(d, nofs) {
  if (all(!is.na(d) & d == 0)) return(c(0, 1))
  n1 <- sum(d > 0, na.rm = TRUE)
  stat <- (n1 - 0.5 * nofs) / (0.5 * sqrt(nofs))
  c(stat, 2 * stats::pnorm(abs(stat), lower.tail = FALSE))
}

# Spacing of floating point numbers: distance from abs(x) to the next larger
# double.
tsx_eps <- function(x) {
  x <- abs(x)
  out <- rep(2^-1074, length(x))
  nz <- x > 0 & is.finite(x)
  out[nz] <- 2^(floor(log2(x[nz])) - 52)
  out
}

# Wilcoxon signed rank test of paired samples (ties within a tolerance):
# returns the sum of ranks of positive differences and the two sided p-value.
tsx_signrank <- function(x, y) {
  d <- x - y
  epsd <- tsx_eps(x) + tsx_eps(y)
  ok <- !is.na(d)
  d <- d[ok]
  epsd <- epsd[ok]
  if (length(d) == 0) return(c(NA_real_, NA_real_))
  nz <- abs(d) > epsd
  d <- d[nz]
  epsd <- epsd[nz]
  n <- length(d)
  if (n == 0) return(c(0, 1))
  # mid ranks of |d| with ties (within tolerance) and tie adjustment
  ad <- abs(d)
  o <- order(ad)
  sx <- ad[o]
  se <- epsd[o]
  ranks <- numeric(n)
  tieadj <- 0
  k <- 1
  while (k <= n) {
    j <- k
    while (j < n && sx[j] + se[j] >= sx[j + 1] - se[j + 1]) j <- j + 1
    ranks[k:j] <- (k + j) / 2
    nt <- j - k + 1
    if (nt > 1) tieadj <- tieadj + nt * (nt - 1) * (nt + 1) / 2
    k <- j + 1
  }
  r <- numeric(n)
  r[o] <- ranks
  w <- sum(r[d > 0])
  if (n <= 15) {
    p <- min(1, 2 * tsx_signrank_exact(r, w))
  } else {
    z <- (w - n * (n + 1) / 4) / sqrt((n * (n + 1) * (2 * n + 1) - tieadj) / 24)
    p <- 2 * stats::pnorm(-abs(z))
  }
  c(w, p)
}

# Probability of the smaller tail of the signed rank
# statistic by counting subsets of ranks.
tsx_signrank_exact <- function(v, w) {
  n <- length(v)
  v <- sort(v)
  maxw <- n * (n + 1) / 2
  if (w > maxw / 2) w <- maxw - w
  if (any(v != floor(v))) {
    v <- round(2 * v)
    w <- round(2 * w)
  }
  w <- floor(w)
  cnt <- numeric(w + 1)
  cnt[1] <- 1
  top <- 1
  for (vj in v[v <= w]) {
    newtop <- min(top + vj, w + 1)
    hi <- if (min(vj, w + 1) + 1 <= newtop) (min(vj, w + 1) + 1):newtop else integer(0)
    lo <- seq_along(hi)
    cnt[hi] <- cnt[hi] + cnt[lo]
    top <- newtop
  }
  sum(cnt) / 2^n
}

#' @export
print.tsx_fcompare <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  cat(strrep("-", 60), "\nForecast Accuracy Comparison Tests\n", strrep("-", 60), "\n",
      "Series: ", x$series, "\n",
      if (!is.null(x$dates)) paste0(tsx_period_text(x$dates), "\n"),
      strrep("-", 60), "\n",
      "H0: Forecasts have equal accuracy\n", strrep("-", 60), "\n",
      "DM:   Diebold and Mariano (1995) Test\nSIGN: Sign Test\n",
      "Wi:   Wilcoxon Signed-Rank Test\n",
      "Truncation value for DM test: ", x$call$trunc, "\n\n", sep = "")
  titles <- c(mse = "Table based on Squared Errors (MSE)",
              mae = "Table based on Absolute Errors (MAE)")
  for (l in names(titles)) {
    t <- x$table[x$table$loss == l, ]
    tsx_cat_block(title = titles[[l]],
                  table = tsx_format_table(t[, c("dm", "p_dm", "sign", "p_sign", "wilcoxon",
                                                 "p_wilcoxon")], digits,
                                           row_names = paste0("F#", t$f1, " vs F#", t$f2, ":"),
                                           col_names = c("DM", "P", "SIGN", "P", "Wi", "P")))
    cat("\n")
  }
  invisible(x)
}

#' Plot of actual values and forecasts
#'
#' Actual values of one series with one or all its forecasts, their
#' confidence bands and the forecast errors, optionally for a subperiod.
#' The returned object holds the data to plot; `plot()` draws it.
#'
#' @inheritParams faccuracy
#' @param forecast Forecast to plot (`1..n`) or `"all"`.
#' @param s Length of the subperiods for the navigation (default 12).
#' @param subsample `0` for the full sample or `k` for the k-th subperiod of
#'   length `s`.
#' @return An object of class `tsx_fplot` with fields `call`, `series`,
#'   `time`, `actual`, `forecasts` (matrix), `lower`, `upper` (matrices of
#'   bands `py -/+ z * stdpy`, or `NULL` without `stdpy`), `errors` (forecast minus actual for one forecast,
#'   absolute errors for all), `origin` and `dates` (date of each row for
#'   dated inputs, otherwise `NULL`).
#' @examples
#' y <- as.vector(log(airpas))
#' p <- fplot(y, cbind(y[121:132], rep(y[132], 12)), forecast = "all")
#' plot(p)
#' # dated forecasts after the end of the data (aligned by their dates)
#' y <- log(airpas)
#' fut <- ts(rep(y[144], 12), start = c(1961, 1), frequency = 12)
#' plot(fplot(y, fut, s = 24, subsample = 6))
#' # with 90% intervals (standard deviations growing with the horizon)
#' plot(fplot(y, fut, 0.03 * sqrt(1:12), level = 0.9, s = 24, subsample = 6))
#' @export
fplot <- function(y, py, stdpy = NULL, origin = 0, series = 1, forecast = 1, s = 12,
                  subsample = 0, level = 0.95, names = NULL) {
  a <- tsx_forecast_align(y, py, stdpy, origin, names, level)
  yy <- a$y
  n <- nrow(yy)
  m <- ncol(yy)
  si <- tsx_series_index(series, yy)[1]
  cc <- tsx_forecast_cols(si, m, a$nf)
  all <- is.character(forecast) && tolower(forecast) == "all"
  fsel <- if (all) seq_len(a$nf) else {
    f <- as.integer(forecast)
    if (is.na(f) || f < 1 || f > a$nf) stop("Invalid 'forecast'.", call. = FALSE)
    f
  }
  s <- min(tsx_check_int(s, "s"), n)
  nsub <- ceiling(n / s)
  subsample <- min(max(0, round(subsample)), nsub)
  t <- if (subsample == 0) seq_len(n) else ((subsample - 1) * s + 1):min(subsample * s, n)
  fc <- a$py[, cc$py[fsel], drop = FALSE]
  colnames(fc) <- paste0("F", fsel)
  lower <- upper <- NULL
  if (!is.null(a$bands)) {
    lower <- a$bands[, cc$lower[fsel], drop = FALSE]
    upper <- a$bands[, cc$upper[fsel], drop = FALSE]
  }
  err <- if (all) abs(yy[, si] - fc) else fc - yy[, si]
  tsx_result("fplot", call = list(series = si, forecast = if (all) "all" else fsel, s = s,
                                  subsample = subsample, n_subsamples = nsub, level = level),
             series = colnames(yy)[si], time = t, actual = yy[, si],
             forecasts = fc, lower = lower, upper = upper, errors = err,
             origin = a$origin, dates = a$dates)
}

#' @export
plot.tsx_fplot <- function(x, ...) {
  t <- x$time
  cols <- c("red", "darkgreen", "magenta3", "gold3", "blue", "cyan3")
  cols <- rep(cols, length.out = ncol(x$forecasts))
  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op))
  graphics::layout(matrix(1:2), heights = c(3, 1))
  graphics::par(mar = c(1, 4, 3, 1))
  finite_range <- function(v) {
    v <- v[is.finite(v)]
    if (length(v) == 0) c(-0.1, 0.1) else range(v)
  }
  yl <- finite_range(c(x$actual, x$forecasts, x$lower, x$upper))
  # horizontal axis: dates when available, otherwise row numbers
  co <- tsx_time_coords(if (is.null(x$dates)) NULL else x$dates[t], t)
  xo <- if (x$origin <= 0) NULL else if (is.null(x$dates)) x$origin
        else as.numeric(x$dates[x$origin])
  graphics::plot(co$x, x$actual[t], type = "l", xlim = co$xlim, ylim = yl, xaxt = "n", xlab = "",
                 ylab = paste("Series", x$series),
                 main = paste0("Series ", x$series,
                               ": Series Plot, Forecast with confidence bands and Errors"))
  for (k in seq_len(ncol(x$forecasts))) {
    graphics::lines(co$x, x$forecasts[t, k], col = cols[k])
    if (!is.null(x$lower)) {
      graphics::lines(co$x, x$lower[t, k], col = cols[k], lty = 3)
      graphics::lines(co$x, x$upper[t, k], col = cols[k], lty = 3)
    }
  }
  if (!is.null(xo)) graphics::abline(v = xo, lwd = 2)
  graphics::legend("topleft", c(x$series, colnames(x$forecasts)),
                   col = c("black", cols), lty = 1, bty = "n", cex = 0.8)
  graphics::par(mar = c(4, 4, 0.5, 1))
  e <- x$errors[t, , drop = FALSE]
  el <- finite_range(e)
  if (el[1] == el[2]) el <- c(-0.1, 0.1)
  if (identical(x$call$forecast, "all")) el[1] <- 0
  graphics::matplot(co$x, e, type = "l", lty = 1, col = cols, xlim = co$xlim, ylim = el,
                    xaxt = "n", xlab = co$lab,
                    ylab = if (identical(x$call$forecast, "all")) "ABS(E)" else "Errors")
  co$axis()
  if (!identical(x$call$forecast, "all")) graphics::abline(h = 0, lty = 3)
  if (!is.null(xo)) graphics::abline(v = xo, lwd = 2)
  invisible(x)
}
