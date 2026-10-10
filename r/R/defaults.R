#' Default options of the tools of tooltest()
#'
#' Single source of the default options of every tool (they depend on the
#' sample size `T` and the number of series `m`). It is used by the [tooltest()] application; the functions of the
#' package resolve the same defaults when their arguments are `NULL`.
#'
#' Some options are linked across tools: the seasonal
#' period `s` (`plotband`, `vboxplot`, `vtboxplot`, `vident`, `vident2`,
#' `stdmean` and the `group` of `vboxcox`), the number of lags of the
#' correlograms (`vident`, `vident2`, `varsbc`), the lags of the unit root
#' tests (`adftest`, `vphillips`, `johansentest`) and the number of lags of
#' the non-linearity tests (`nltests`, `varsbc2`). The groups are returned in
#' the attribute `"links"`.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param ... Options to override, given as named lists per tool, e.g.
#'   `vident = list(ncoef = 50, s = 4, npar = 1)`. Unnamed elements are
#'   assigned in the order of the options of the tool, e.g.
#'   `varspectrum = list(16)`. When a linked option is changed in one tool,
#'   it is propagated to the other tools of its group.
#' @return A named list (one element per tool) of named lists of options,
#'   with attribute `"links"`.
#' @examples
#' str(tooltest_defaults(airpas)$vident)
#' tooltest_defaults(airpas, vboxplot = list(s = 4))$plotband$s
#' @export
tooltest_defaults <- function(y, ...) {
  y <- as_tsx_matrix(y)
  n <- nrow(y)
  m <- ncol(y)
  lmax <- min(floor(sqrt(n)), 20)
  ur_lags <- if (m == 1) seq_len(lmax) else lmax
  nc_acf <- min(38, ceiling(n / 4 / m * 2))
  nc_nl <- min(38, ceiling(sqrt(n)))
  def <- list(
    plotband = list(s = 12, standard = FALSE, fixed = TRUE),
    vboxplot = list(s = 12),
    vtboxplot = list(s = 12),
    vscatter = list(bins = ceiling(sqrt(n))),
    sumstats = list(digits = 4, gaussian = TRUE, nsimul = 3000),
    vhist = list(bins = ceiling(sqrt(n))),
    vqqplot = list(),
    gausstest = list(digits = 4),
    vident = list(ncoef = nc_acf, s = 12, npar = 0),
    vident2 = list(ncoef = nc_acf, s = 12, npar = 0, type = 0),
    varsbc = list(ncoef = nc_acf),
    vgranger = list(lags = seq_len(lmax), tests = if (m > 1) tsx_granger_tests(NULL, m) else NULL),
    vcusum = list(),
    stdmean = list(s = 12, type = 0, numbers = TRUE),
    testhet = list(timecuts = c(floor(n / 3), floor(2 * n / 3) + 2)),
    vboxcox = list(group = 12, axislambdas = seq(-1, 1, by = 0.1)),
    adftest = list(lags = ur_lags),
    vphillips = list(lags = ur_lags, ncovs = floor(4 * (n / 100)^0.25)),
    johansentest = list(lags = ur_lags),
    nltests = list(ncoef = nc_nl),
    vtsay = list(lags = 4),
    varsbc2 = list(ncoef = nc_nl),
    vbds = list(maxdim = 2, distance = 1.5),
    vcumperiod = list(),
    vspectrum = list(smooth = 1, xlog = c(FALSE, TRUE)),
    varspectrum = list(order = 16, nfreq = floor(n / 2), xlog = c(FALSE, TRUE))
  )
  links <- list(
    s = list(c("plotband", "s"), c("vboxplot", "s"), c("vtboxplot", "s"), c("vident", "s"),
             c("vident2", "s"), c("stdmean", "s"), c("vboxcox", "group")),
    ncoef_acf = list(c("vident", "ncoef"), c("vident2", "ncoef"), c("varsbc", "ncoef")),
    lags_unitroot = list(c("adftest", "lags"), c("vphillips", "lags"), c("johansentest", "lags")),
    ncoef_nl = list(c("nltests", "ncoef"), c("varsbc2", "ncoef"))
  )
  over <- list(...)
  if (length(over)) {
    if (is.null(names(over)) || any(names(over) == "")) {
      stop("Options must be given as named lists, e.g. vident = list(ncoef = 20).", call. = FALSE)
    }
    out <- def
    for (tool in names(over)) {
      if (!tool %in% names(def)) stop("Unknown tool: ", tool, call. = FALSE)
      val <- over[[tool]]
      if (!is.list(val)) val <- list(val)
      onames <- names(def[[tool]])
      nm <- names(val)
      if (is.null(nm)) nm <- rep("", length(val))
      for (k in seq_along(val)) {
        key <- if (nm[k] != "") nm[k] else onames[k]
        if (is.na(key) || !key %in% onames) {
          stop("Unknown option for ", tool, ": ", if (nm[k] != "") nm[k] else k, call. = FALSE)
        }
        if (!is.null(val[[k]])) out[[tool]][[key]] <- val[[k]]
      }
    }
    # Propagate linked options (the last changed member of each group wins,
    # in a fixed order).
    for (g in links) {
      changed <- NULL
      for (mem in g) {
        if (!identical(out[[mem[1]]][[mem[2]]], def[[mem[1]]][[mem[2]]])) {
          changed <- out[[mem[1]]][[mem[2]]]
        }
      }
      if (!is.null(changed)) for (mem in g) out[[mem[1]]][[mem[2]]] <- changed
    }
    def <- out
  }
  attr(def, "links") <- links
  def
}
