#' tsexplorer: exploratory, descriptive and diagnostic tools for time series
#'
#' Exploratory, descriptive and diagnostic tools for univariate and
#' multivariate time series, and tools to evaluate and compare forecasts
#' (Diego J. Pedregal, Universidad de Castilla-La Mancha).
#'
#' Every tool is a pure function that takes a `T x m` data set (time in rows,
#' series in columns; see [as_tsx_matrix()]) and returns an object of class
#' `c("tsx_<function>", "tsx_result")` with `print()` and, when relevant,
#' `plot()` methods. The graphical interfaces [tooltest()] and
#' [toolforecast()] (Tcl/Tk windows or Shiny applications) give interactive
#' access to all of them.
#'
#' In an interactive session, printing a result (for example typing
#' `vident(y)` or `plotband(y)` at the console) sends its table to a text
#' window and its plot to a graphics window. [tooltest()] and
#' [toolforecast()] have independent windows, one text window and one
#' graphics window each: the results of the tools of [tooltest()] go to its
#' windows and those of [faccuracy()], [fcompare()] and [fplot()] to the
#' windows of [toolforecast()] (the windows of the interface if it is open).
#' Each output replaces the previous one, and a new call of [tooltest()] or
#' [toolforecast()] reuses its own windows and brings them to the front.
#' Assigning the result (`res <- vident(y)`) shows nothing;
#' `print(res, window = FALSE)` prints the text at the console and `plot(res)`
#' draws on the current graphics device. In scripts, tests and documents
#' (non interactive sessions), or with `options(tsexplorer.window = FALSE)`,
#' `print()` writes to the console. Without Tcl/Tk the text goes to the
#' console and the plot to the current graphics device.
#'
#' * Plots and descriptive statistics: [plotband()], [vboxplot()],
#'   [vtboxplot()], [vscatter()], [sumstats()], [vhist()], [vqqplot()],
#'   [gausstest()].
#' * Identification: [vident()], [vident2()], [varsbc()], [vgranger()].
#' * Heteroskedasticity: [vcusum()], [stdmean()], [testhet()], [vboxcox()].
#' * Unit roots and cointegration: [adftest()], [vphillips()],
#'   [johansentest()].
#' * Non-linearity: [nltests()], [vtsay()], [varsbc2()], [vbds()].
#' * Spectral analysis: [vcumperiod()], [vspectrum()], [varspectrum()].
#' * Forecast evaluation: [faccuracy()], [fcompare()], [fplot()].
#' * Utilities: [as_tsx_matrix()], [vdif()], [meda()], [adfcritical()],
#'   [tooltest_defaults()].
#'
#' @keywords internal
"_PACKAGE"
