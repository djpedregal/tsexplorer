# Code shared by the two graphical interfaces of tooltest() and
# toolforecast() (Shiny and tcltk). Nothing here depends on a GUI toolkit:
# it describes the tools, converts the values typed by the user into options
# and calls the exported functions of the package. Both interfaces must use
# these functions so that they behave identically.

# Registry of the tools of the Tests menu (menu order and
# groups). series: how the series are selected; multi: needs m > 1.
tsx_tools <- function() {
  o <- function(name, label, type, ...) list(name = name, label = label, type = type, ...)
  list(
    plotband = list(label = "Plot", group = "Plots and statistics", fun = plotband,
                    series = "single_all", plot = TRUE, nav = "subsample",
                    options = list(o("s", "Seasonal period for plots [2, Inf)", "int", min = 2),
                                   o("standard", "Standardized plot (all series)", "logical"),
                                   o("fixed", "Fixed vertical scale", "logical"))),
    vboxplot = list(label = "Boxplot", group = "Plots and statistics", fun = vboxplot,
                    series = "single", plot = TRUE, nav = "highlight",
                    options = list(o("s", "Seasonal period for box plots [2, Inf)", "int", min = 2))),
    vtboxplot = list(label = "Transpose boxplot", group = "Plots and statistics", fun = vtboxplot,
                     series = "single", plot = TRUE, nav = "highlight",
                     options = list(o("s", "Seasonal period [2, Inf)", "int", min = 2))),
    vscatter = list(label = "Scatter plots", group = "Plots and statistics", fun = vscatter,
                    series = "pair_all", plot = TRUE, multi = TRUE,
                    options = list(o("bins", "Number of bins for histograms [4, Inf)", "int", min = 4))),
    sumstats = list(label = "Summary statistics (table)", group = "Plots and statistics",
                    fun = sumstats, series = "none", plot = FALSE,
                    options = list(o("digits", "Number of decimals [0, Inf)", "int", min = 0),
                                   o("gaussian", "Gaussian distribution for the mean test", "logical"),
                                   o("nsimul", "Simulations for the empirical mean test", "int", min = 10))),
    vhist = list(label = "Histogram", group = "Distribution", fun = vhist, series = "single",
                 plot = TRUE, options = list(o("bins", "Number of bins [4, Inf)", "int", min = 4))),
    vqqplot = list(label = "QQ plot", group = "Distribution", fun = vqqplot, series = "single",
                   plot = TRUE, options = list()),
    gausstest = list(label = "Gaussianity tests (table)", group = "Distribution", fun = gausstest,
                     series = "none", plot = FALSE,
                     options = list(o("digits", "Number of decimals [0, Inf)", "int", min = 0))),
    vident = list(label = "Univariate ACF and PACF", group = "Identification", fun = vident,
                  series = "single", plot = TRUE,
                  options = list(o("ncoef", "Number of lags [4, Inf)", "int", min = 4),
                                 o("s", "Seasonal period [2, Inf)", "int", min = 2),
                                 o("npar", "Number of model parameters [0, Inf)", "int", min = 0))),
    vident2 = list(label = "Vector ACF and PACF", group = "Identification", fun = vident2,
                   series = "pair", plot = TRUE, multi = TRUE, series_in_plot = TRUE,
                   options = list(o("ncoef", "Number of lags [4, Inf)", "int", min = 4),
                                  o("s", "Seasonal period [2, Inf)", "int", min = 2),
                                  o("npar", "Number of model parameters [0, Inf)", "int", min = 0),
                                  o("type", "Partial function", "select",
                                    choices = c("Partial lag autocorrelations" = 0,
                                                "Partial autoregressions" = 1)))),
    varsbc = list(label = "Information criteria", group = "Identification", fun = varsbc,
                  series = "var", plot = TRUE,
                  options = list(o("ncoef", "Maximum order [1, Inf)", "int", min = 1))),
    vgranger = list(label = "Granger causality tests (table)", group = "Identification",
                    fun = vgranger, series = "none", plot = FALSE, multi = TRUE,
                    options = list(o("lags", "Lags of the VAR (e.g. 1:4 or 1 2 12)", "intvec"),
                                   o("tests", "Tests (e.g. a-b ab-c)", "text"))),
    vcusum = list(label = "CUSUM and CUSUMSQ", group = "Heteroskedasticity", fun = vcusum,
                  series = "single", plot = TRUE, options = list()),
    stdmean = list(label = "S.D.-Mean and MEDA-Median plots", group = "Heteroskedasticity",
                   fun = stdmean, series = "single", plot = TRUE,
                   options = list(o("s", "Seasonal period [2, Inf)", "int", min = 2),
                                  o("type", "Type of plot", "select",
                                    choices = c("S.D. vs Mean" = 0, "MEDA vs Median" = 1,
                                                "Range vs Mean" = 2)),
                                  o("numbers", "Numbers on/off", "logical"))),
    testhet = list(label = "Heteroskedasticity tests (table)", group = "Heteroskedasticity",
                   fun = testhet, series = "none", plot = FALSE,
                   options = list(o("timecuts", "Time cuts (e.g. 48 96, or 1 30; 50 90)", "matrix"))),
    vboxcox = list(label = "Box-Cox transformation", group = "Heteroskedasticity", fun = vboxcox,
                   series = "single", plot = TRUE,
                   options = list(o("group", "Observations per group [2, Inf)", "int", min = 2),
                                  o("axislambdas", "Lambdas for plots (e.g. -1:0.1:1)", "numvec"))),
    adftest = list(label = "Augmented Dickey-Fuller test (table)", group = "Unit roots",
                   fun = adftest, series = "none", plot = FALSE,
                   options = list(o("lags", "Lags (e.g. 1:10)", "intvec"))),
    vphillips = list(label = "Phillips-Perron test (table)", group = "Unit roots", fun = vphillips,
                     series = "none", plot = FALSE,
                     options = list(o("lags", "Lags (e.g. 1:10)", "intvec"),
                                    o("ncovs", "Number of covariances [0, Inf)", "int", min = 0))),
    johansentest = list(label = "Johansen test (table)", group = "Unit roots", fun = johansentest,
                        series = "none", plot = FALSE,
                        options = list(o("lags", "Lags (e.g. 3 or 2:6)", "intvec"))),
    nltests = list(label = "MLL, MT and PR non-linearity tests", group = "Non-linearity",
                   fun = nltests, series = "single", plot = TRUE,
                   options = list(o("ncoef", "Number of lags [4, Inf)", "int", min = 4))),
    vtsay = list(label = "Tsay (1986) non-linearity test (table)", group = "Non-linearity",
                 fun = vtsay, series = "none", plot = FALSE,
                 options = list(o("lags", "Lags of the AR model [2, Inf)", "int", min = 2))),
    varsbc2 = list(label = "SBC of squares", group = "Non-linearity", fun = varsbc2,
                   series = "single", plot = TRUE,
                   options = list(o("ncoef", "Maximum order [1, Inf)", "int", min = 1))),
    vbds = list(label = "BDS test (table)", group = "Non-linearity", fun = vbds, series = "none",
                plot = FALSE,
                options = list(o("maxdim", "Maximum dimension [2, T/2)", "int", min = 2),
                               o("distance", "Distance as a fraction of the S.D. (0, Inf)", "num",
                                 min = 0.01))),
    vcumperiod = list(label = "Cumulative periodogram", group = "Spectral", fun = vcumperiod,
                      series = "single", plot = TRUE, options = list()),
    vspectrum = list(label = "Spectrum", group = "Spectral", fun = vspectrum, series = "pair",
                     plot = TRUE,
                     options = list(o("smooth", "Length of triangular window [1, T/4)", "int", min = 1),
                                    o("xlog", "Log scale (period axis, power axis)", "logical2"))),
    varspectrum = list(label = "VAR spectrum", group = "Spectral", fun = varspectrum,
                       series = "single", plot = TRUE,
                       options = list(o("order", "Order of AR model [1, T/4]", "int", min = 1),
                                      o("nfreq", "Number of frequencies (0 for Fourier)", "int", min = 0),
                                      o("xlog", "Log scale (period axis, power axis)", "logical2")))
  )
}

# Parse a numeric vector or matrix written in a text box:
# "1:10", "1 2 12", "c(1, 3)", "-1:0.1:1", "1 30; 50 90". No code is evaluated.
tsx_parse_numbers <- function(txt, matrix = FALSE) {
  txt <- gsub("c\\(|\\)|\\[|\\]", " ", as.character(txt))
  txt <- gsub("[[:space:]]*:[[:space:]]*", ":", txt)
  rows <- strsplit(txt, ";", fixed = TRUE)[[1]]
  parse_row <- function(r) {
    tok <- strsplit(trimws(r), "[[:space:],]+")[[1]]
    tok <- tok[tok != ""]
    out <- numeric(0)
    for (tk in tok) {
      parts <- suppressWarnings(as.numeric(strsplit(tk, ":", fixed = TRUE)[[1]]))
      if (anyNA(parts)) stop("Invalid number: ", tk, call. = FALSE)
      if (length(parts) == 1) out <- c(out, parts)
      else if (length(parts) == 2) out <- c(out, seq(parts[1], parts[2]))
      else out <- c(out, seq(parts[1], parts[3], by = parts[2]))
    }
    out
  }
  vals <- lapply(rows, parse_row)
  vals <- vals[lengths(vals) > 0]
  if (length(vals) == 0) return(NULL)
  if (matrix && length(vals) > 1) return(do.call(rbind, vals))
  unlist(vals)
}

tsx_format_numbers <- function(x) {
  if (is.null(x)) return("")
  if (is.matrix(x) && nrow(x) > 1) {
    return(paste(apply(x, 1, paste, collapse = " "), collapse = "; "))
  }
  x <- as.vector(x)
  if (length(x) > 2 && all(diff(x) == 1)) return(paste0(x[1], ":", x[length(x)]))
  d <- diff(x)
  if (length(x) > 2 && all(abs(d - d[1]) < 1e-9)) {
    return(paste0(x[1], ":", signif(d[1], 6), ":", x[length(x)]))
  }
  paste(x, collapse = " ")
}

# Arguments of the call to the core function of a tool.
tsx_gui_args <- function(tool, spec, opts, series, nav) {
  args <- opts[[tool]]
  if (!is.null(spec$series_in_plot) && spec$series_in_plot) {
    # vident2: the pair of series is an argument of plot()
  } else if (spec$series != "none") {
    args$series <- series
  }
  if (identical(spec$nav, "subsample")) {
    args$subsample <- nav$subsample
    args$overlay <- nav$overlay
  }
  if (identical(spec$nav, "highlight")) args$highlight <- nav$highlight
  args
}

# Tools of the Tests menu available for m series (tools needing several
# series are removed when m = 1).
tsx_tools_for <- function(m) {
  tools <- tsx_tools()
  if (m == 1) tools <- tools[!vapply(tools, function(t) isTRUE(t$multi), logical(1))]
  tools
}

# Convert the value typed or selected in the GUI into the value of an option.
# Text boxes are parsed with tsx_parse_numbers() (no code is evaluated).
tsx_gui_parse_option <- function(op, value) {
  switch(op$type,
         int = {
           v <- suppressWarnings(as.integer(round(as.numeric(value))))
           if (length(v) != 1 || is.na(v)) stop(op$label, ": a number is expected.", call. = FALSE)
           if (!is.null(op$min) && v < op$min) stop(op$label, ": the minimum is ", op$min, ".",
                                                   call. = FALSE)
           v
         },
         num = {
           v <- suppressWarnings(as.numeric(value))
           if (length(v) != 1 || is.na(v)) stop(op$label, ": a number is expected.", call. = FALSE)
           if (!is.null(op$min) && v < op$min) stop(op$label, ": the minimum is ", op$min, ".",
                                                   call. = FALSE)
           if (!is.null(op$max) && v > op$max) stop(op$label, ": the maximum is ", op$max, ".",
                                                   call. = FALSE)
           v
         },
         logical = isTRUE(as.logical(value)),
         logical2 = as.logical(rep_len(value, 2)),
         select = as.numeric(value),
         text = if (is.null(value) || trimws(paste(value, collapse = " ")) == "") NULL
                else paste(value, collapse = " "),
         intvec = as.integer(tsx_parse_numbers(value)),
         numvec = tsx_parse_numbers(value),
         matrix = tsx_parse_numbers(value, matrix = TRUE))
}

# Text shown in a text box for the current value of an option.
tsx_gui_option_text <- function(op, value) {
  switch(op$type,
         text = paste(value, collapse = " "),
         intvec = , numvec = , matrix = tsx_format_numbers(value),
         as.character(value))
}

# Set an option of a tool and propagate it to the linked options
# (attribute "links" of tooltest_defaults()).
tsx_gui_set_option <- function(opts, tool, name, value) {
  links <- attr(opts, "links")
  opts[[tool]][name] <- list(value)
  for (g in links) {
    hit <- vapply(g, function(mem) mem[1] == tool && mem[2] == name, logical(1))
    if (any(hit)) for (mem in g) opts[[mem[1]]][mem[2]] <- list(value)
  }
  opts
}

# Series selection given the selection mode of a tool: s1, s2 are indices,
# all = TRUE selects "all" when the mode allows it.
tsx_gui_series <- function(mode, s1 = 1L, s2 = NULL, all = FALSE) {
  s1 <- as.integer(s1)
  switch(mode,
         none = NULL,
         single = s1,
         single_all = , var = if (isTRUE(all)) "all" else s1,
         pair = {
           s2 <- if (is.null(s2)) s1 else as.integer(s2)
           if (s1 == s2) s1 else c(s1, s2)
         },
         pair_all = if (isTRUE(all)) "all" else c(s1, if (is.null(s2)) 2L else as.integer(s2)))
}

# Run a tool: returns the call made to the core (tool and arguments) and the
# result (or the error).
tsx_gui_run <- function(y, tool, opts, series, nav) {
  spec <- tsx_tools()[[tool]]
  args <- tsx_gui_args(tool, spec, opts, series, nav)
  res <- tryCatch(do.call(spec$fun, c(list(y), args)), error = function(e) e)
  list(call = list(tool = tool, args = args), result = res)
}

# Plot the result of a tool (in the current graphics device).
tsx_gui_plot <- function(result, tool, series) {
  spec <- tsx_tools()[[tool]]
  if (inherits(result, "error") || !isTRUE(spec$plot)) {
    graphics::plot.new()
    if (inherits(result, "error")) graphics::title(conditionMessage(result), cex.main = 0.8)
    return(invisible())
  }
  if (isTRUE(spec$series_in_plot)) plot(result, series = series) else plot(result)
  invisible()
}

# Text output of a tool (what print() shows), as a character vector.
tsx_gui_text <- function(result, error = NULL) {
  out <- character(0)
  if (!is.null(error)) out <- c(out, paste("Error in options:", error), "")
  if (inherits(result, "error")) return(c(out, paste("Error:", conditionMessage(result))))
  c(out, utils::capture.output(print(result, window = FALSE)))
}

# Tables of toolforecast(): accuracy measures of every forecast and, with two
# or more forecasts, the comparison tests. When the actual values and the
# forecasts do not overlap there are no accuracy tables (accuracy = NULL,
# no_overlap = TRUE) and 'forecasts' is the fplot() object of all the
# forecasts, for the table of the forecasts only.
tsx_fgui_tables <- function(y, py, stdpy, origin, series, trunc, level, names, nf) {
  acc <- tryCatch(faccuracy(y, py, stdpy, origin = origin, series = series, level = level,
                            names = names),
                  error = function(e) e)
  if (inherits(acc, "tsx_no_overlap")) {
    fc <- tryCatch(fplot(y, py, stdpy, origin = origin, series = series, forecast = "all",
                         level = level, names = names), error = function(e) e)
    return(list(accuracy = NULL, compare = NULL, no_overlap = TRUE, forecasts = fc))
  }
  cmp <- NULL
  if (nf > 1) {
    cmp <- tryCatch(fcompare(y, py, origin = origin, trunc = trunc, series = series,
                             names = names), error = function(e) e)
  }
  list(accuracy = acc, compare = cmp, no_overlap = FALSE)
}

# Text of the tables of toolforecast(): for one forecast the measures
# accumulated by horizon, for all of them the summary table and the tests.
tsx_fgui_text <- function(tables, forecast) {
  if (isTRUE(tables$no_overlap)) return(tsx_fgui_forecast_text(tables$forecasts, forecast))
  acc <- tables$accuracy
  if (inherits(acc, "error")) return(paste("Error:", conditionMessage(acc)))
  if (identical(forecast, "all")) {
    out <- utils::capture.output(print(acc, window = FALSE))
    cmp <- tables$compare
    if (!is.null(cmp)) {
      out <- c(out, "", if (inherits(cmp, "error")) paste("Error:", conditionMessage(cmp))
                        else utils::capture.output(print(cmp, window = FALSE)))
    }
    return(out)
  }
  h <- acc$by_horizon
  h <- h[h$forecast == forecast, setdiff(names(h), "forecast")]
  h <- h[, vapply(h, function(v) !all(is.na(v)), logical(1)), drop = FALSE]
  if (!is.null(h$date)) h$date <- tsx_format_dates(h$date)
  utils::capture.output(tsx_cat_block(
    title = c("Forecasting Results", paste0("Series ", acc$series, ", Forecast #", forecast),
              tsx_period_text(acc$dates)),
    notes = "Measures accumulated up to each period",
    table = tsx_format_table(h, c(0, rep(3, ncol(h) - 1)),
                             col_names = sub("^bias_mae$", "bias+mae", names(h)))))
}

# Text of toolforecast() when there are no actual values in the forecasting
# period (out of sample forecasts): the table of the forecasts, without
# actual values nor error measures. 'p' is the fplot() object of all the
# forecasts of the series. For one forecast the table has the forecast and,
# with standard deviations, the bounds of its intervals; for all of them,
# the forecasts side by side.
tsx_fgui_forecast_text <- function(p, forecast) {
  if (!inherits(p, "tsx_fplot")) {
    return(c("No actual values in the forecasting period: no accuracy measures.",
             if (inherits(p, "error")) paste("Error:", conditionMessage(p))))
  }
  fc <- p$forecasts
  tt <- seq_len(nrow(fc))
  tt <- tt[tt > p$origin & rowSums(!is.na(fc)) > 0]
  all <- identical(forecast, "all")
  k <- if (all) seq_len(ncol(fc)) else as.integer(forecast)
  tab <- data.frame(t = tt)
  if (!is.null(p$dates)) tab$date <- tsx_format_dates(p$dates[tt])
  if (all) {
    for (j in k) tab[[paste0("F#", j)]] <- fc[tt, j]
  } else {
    tab$fcst <- fc[tt, k]
    if (!is.null(p$lower)) {
      tab$lower <- p$lower[tt, k]
      tab$upper <- p$upper[tt, k]
    }
  }
  nnum <- ncol(tab) - if (is.null(p$dates)) 1 else 2
  lv <- p$call$level
  notes <- c("No actual values in the forecasting period: forecasts only",
             if (!all && !is.null(p$lower))
               paste0("lower, upper: bounds of the ", format(100 * lv), "% prediction intervals"))
  utils::capture.output(tsx_cat_block(
    title = c("Forecasting Results",
              paste0("Series ", p$series, if (all) ", all forecasts" else paste0(", Forecast #", k)),
              tsx_period_text(if (is.null(p$dates)) NULL else p$dates[tt])),
    notes = notes,
    table = tsx_format_table(tab, c(rep(0, ncol(tab) - nnum), rep(3, nnum)))))
}

# Check that the requested interface is available.
tsx_check_gui <- function(gui) {
  if (gui == "shiny") {
    if (!requireNamespace("shiny", quietly = TRUE)) {
      stop("The package 'shiny' is needed for gui = \"shiny\". Install it with ",
           "install.packages(\"shiny\") or use gui = \"tcltk\".", call. = FALSE)
    }
  } else {
    if (!isTRUE(capabilities("tcltk")) || !requireNamespace("tcltk", quietly = TRUE)) {
      stop("This R installation has no Tcl/Tk support, needed for gui = \"tcltk\". ",
           "Use gui = \"shiny\".", call. = FALSE)
    }
  }
}

# Plot object of toolforecast(): returns the call made to fplot() and its
# result (or the error).
tsx_fgui_run <- function(y, py, stdpy, origin, names, series, forecast, s, subsample,
                         level = 0.95) {
  args <- list(origin = origin, series = series, forecast = forecast, s = s,
               subsample = subsample, level = level, names = names)
  res <- tryCatch(do.call(fplot, c(list(y, py, stdpy), args)), error = function(e) e)
  list(call = list(fun = "fplot", args = args), result = res)
}

tsx_fgui_plot <- function(p) {
  if (inherits(p, "error")) {
    graphics::plot.new()
    graphics::title(conditionMessage(p), cex.main = 0.8)
  } else {
    plot(p)
  }
  invisible()
}
