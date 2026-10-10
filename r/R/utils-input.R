# Input handling shared by every function of the package.
# All the computational code only ever sees a numeric T x m matrix with
# column names (time in rows, series in columns).

#' Convert input data to the matrix format used by tsexplorer
#'
#' Every function of the package accepts data without dates (numeric vector,
#' matrix or numeric `data.frame`) or with dates (`ts`, `mts`, `zoo`, `xts`
#' or a `data.frame` with one date column) and converts it with this function
#' into a numeric `T x m` matrix (rows are time, columns are series) with
#' column names.
#'
#' The dates, when available, are kept in the attribute `"dates"` of the
#' matrix (one per row) and are used in the time axes of the plots and in
#' the tables of the forecasting tools. They are:
#' * `Date` for `ts` objects with frequency 1, 4 or 12 (first day of each
#'   year, quarter or month), for `zoo`/`xts` objects indexed by `Date` and
#'   for `data.frame` objects with a `Date` column;
#' * `POSIXct` for date-time indices or columns;
#' * numbers (the time of the `ts` object, or a numeric `zoo` index) in the
#'   other cases.
#'
#' Dates must be increasing and without repetitions.
#'
#' @param y Numeric vector, matrix, `ts`, `mts`, `zoo`, `xts` or
#'   `data.frame` (numeric columns and, optionally, one column of class
#'   `Date` or `POSIXct`).
#' @param names Optional character vector with the names of the series. If
#'   shorter than the number of series, the remaining ones take the default
#'   names `"#1"`, `"#2"`, ... A single string with blank-separated names is
#'   also accepted.
#' @param trim If `TRUE` (default), rows at the beginning and at the end of
#'   the sample where all the series are missing are removed.
#' @return A numeric matrix with column names and, for dated inputs, the
#'   attribute `"dates"`.
#' @examples
#' as_tsx_matrix(airpas)[1:3, , drop = FALSE]
#' as_tsx_matrix(cbind(a = 1:5, b = c(NA, 2:5)))
#' d <- data.frame(date = as.Date("2024-01-01") + 0:4, x = c(3, 1, 4, 1, 5))
#' attr(as_tsx_matrix(d), "dates")
#' @export
as_tsx_matrix <- function(y, names = NULL, trim = TRUE) {
  parts <- tsx_input_parts(y)
  y <- parts$values
  dates <- parts$dates
  if (is.data.frame(y)) {
    ok <- vapply(y, is.numeric, logical(1))
    if (!all(ok)) {
      stop("All the columns of 'y' must be numeric (except one date column).", call. = FALSE)
    }
    y <- as.matrix(y)
  }
  if (is.null(y) || length(y) == 0) stop("'y' is empty.", call. = FALSE)
  if (!is.numeric(y) && !is.logical(y)) {
    stop("'y' must be numeric (vector, matrix, ts or data.frame).", call. = FALSE)
  }
  cn <- colnames(y)
  if (is.null(dim(y))) {
    y <- matrix(as.numeric(y), ncol = 1)
  } else {
    if (length(dim(y)) != 2) stop("'y' must have at most two dimensions.", call. = FALSE)
    y <- matrix(as.numeric(y), nrow = nrow(y), ncol = ncol(y))
  }
  y[is.nan(y)] <- NA
  m <- ncol(y)
  colnames(y) <- tsx_names(m, if (is.null(names)) cn else names)
  if (!is.null(dates) && length(dates) != nrow(y)) {
    stop("The number of dates and of observations of 'y' differ.", call. = FALSE)
  }
  if (trim) {
    y <- tsx_remove_nan(y)
    idx <- attr(y, "index")
    if (!is.null(dates) && !is.null(idx)) dates <- dates[idx]
  }
  if (nrow(y) == 0) stop("'y' contains only missing values.", call. = FALSE)
  attr(y, "dates") <- dates
  y
}

# Values, dates and type of an input object. type is "ts", "xts", "zoo",
# "data.frame" (with a date column), "dated" (a matrix returned by
# as_tsx_matrix() with dates) or "undated"; dates is NULL for "undated".
tsx_input_parts <- function(y) {
  if (stats::is.ts(y)) {
    return(list(values = y, dates = tsx_ts_dates(stats::time(y), stats::frequency(y)),
                type = "ts"))
  }
  if (inherits(y, "zoo")) {
    type <- if (inherits(y, "xts")) "xts" else "zoo"
    for (pkg in unique(c("zoo", type))) {
      if (!requireNamespace(pkg, quietly = TRUE)) {
        stop("The package '", pkg, "' is needed to read ", type, " objects.", call. = FALSE)
      }
    }
    return(list(values = zoo::coredata(y), dates = tsx_check_dates(zoo::index(y)),
                type = type))
  }
  if (is.data.frame(y)) {
    isdate <- vapply(y, function(v) inherits(v, c("Date", "POSIXt")), logical(1))
    if (sum(isdate) > 1) stop("'y' has more than one date column.", call. = FALSE)
    if (sum(isdate) == 1) {
      return(list(values = y[!isdate], dates = tsx_check_dates(y[[which(isdate)]]),
                  type = "data.frame"))
    }
    return(list(values = y, dates = NULL, type = "undated"))
  }
  dates <- attr(y, "dates")
  if (!is.null(dates)) {
    attr(y, "dates") <- NULL
    return(list(values = y, dates = dates, type = "dated"))
  }
  list(values = y, dates = NULL, type = "undated")
}

# Dates of a ts object: Date for frequencies 1, 4 and 12 (first day of the
# year, quarter or month), the numeric time otherwise.
tsx_ts_dates <- function(time, freq) {
  time <- as.numeric(time)
  if (!freq %in% c(1, 4, 12)) return(time)
  k <- round(time * freq)
  year <- k %/% freq
  month <- (k %% freq) * (12 / freq) + 1
  as.Date(sprintf("%04d-%02d-01", as.integer(year), as.integer(month)))
}

# Normalise and check a vector of dates: Date, POSIXct or numeric (other
# numeric classes, such as yearmon, become plain numbers); increasing and
# without repetitions.
tsx_check_dates <- function(d) {
  # rebuild Date and POSIXct vectors to drop extra attributes (e.g. of xts)
  if (inherits(d, "Date")) {
    d <- structure(as.numeric(unclass(d)), class = "Date")
  } else if (inherits(d, "POSIXt")) {
    d <- as.POSIXct(d)
    tz <- attr(d, "tzone")
    d <- structure(as.numeric(unclass(d)), class = c("POSIXct", "POSIXt"),
                   tzone = if (is.null(tz)) "" else tz[1])
  } else if (is.numeric(unclass(d))) {
    d <- as.numeric(unclass(d))
  } else {
    stop("Unsupported type of dates: ", class(d)[1], ".", call. = FALSE)
  }
  if (anyNA(d) || is.unsorted(d, strictly = TRUE)) {
    stop("The dates must be increasing, without repetitions or missing values.", call. = FALSE)
  }
  d
}

# Kind of a vector of dates ("Date", "POSIXct" or "numeric").
tsx_date_kind <- function(d) {
  if (inherits(d, "Date")) "Date" else if (inherits(d, "POSIXct")) "POSIXct" else "numeric"
}

# Dates as text for the tables: "%Y-%m" when all the dates are first days of
# months, "%Y-%m-%d" for other dates, date-time or numbers otherwise.
tsx_format_dates <- function(d) {
  if (is.null(d)) return(NULL)
  if (inherits(d, "Date")) {
    ok <- !is.na(d)
    fmt <- if (all(format(d[ok], "%d") == "01")) "%Y-%m" else "%Y-%m-%d"
    return(ifelse(ok, format(d, fmt), "NA"))
  }
  if (inherits(d, "POSIXct")) return(format(d, "%Y-%m-%d %H:%M:%S"))
  format(d)
}

# Default and user supplied names of the series ("#1", "#2", ...).
tsx_names <- function(m, names = NULL) {
  def <- paste0("#", seq_len(m))
  if (is.null(names)) return(def)
  names <- as.character(names)
  if (length(names) == 1 && m > 1) {
    names <- strsplit(trimws(names), "[[:space:]]+")[[1]]
  }
  out <- def
  k <- min(length(names), m)
  if (k > 0) {
    given <- names[seq_len(k)]
    ok <- !is.na(given) & given != ""
    out[seq_len(k)][ok] <- given[ok]
  }
  out
}

# Remove rows with all the series missing at the beginning and end of the
# sample. Returns the trimmed matrix; attribute "index" keeps
# the rows that were retained.
tsx_remove_nan <- function(y) {
  allna <- rowSums(!is.na(y)) == 0
  if (!any(allna)) {
    attr(y, "index") <- NULL
    return(y)
  }
  ok <- which(!allna)
  if (length(ok) == 0) return(y[0, , drop = FALSE])
  idx <- ok[1]:ok[length(ok)]
  out <- y[idx, , drop = FALSE]
  attr(out, "index") <- idx
  out
}

# Resolve a series selector (index or name) into a column index.
# 'allow_all' accepts "all" and returns all the columns.
tsx_series_index <- function(series, y, allow_all = FALSE) {
  m <- ncol(y)
  if (is.null(series)) series <- 1
  if (is.character(series)) {
    if (allow_all && length(series) == 1 && tolower(series) == "all") {
      return(seq_len(m))
    }
    idx <- match(series, colnames(y))
    if (anyNA(idx)) {
      stop("Series not found: ", paste(series[is.na(idx)], collapse = ", "),
           call. = FALSE)
    }
    return(idx)
  }
  series <- as.integer(series)
  if (any(is.na(series)) || any(series < 1) || any(series > m)) {
    stop("'series' must be between 1 and ", m, ".", call. = FALSE)
  }
  series
}

# Check a single positive integer option.
tsx_check_int <- function(x, name, min = 1) {
  if (length(x) != 1 || is.na(x) || !is.numeric(x) || x < min) {
    stop("'", name, "' must be a single number >= ", min, ".", call. = FALSE)
  }
  as.integer(round(x))
}

# Constructor of the result objects of the package.
tsx_result <- function(fun, ...) {
  structure(list(...), class = c(paste0("tsx_", fun), "tsx_result"))
}
