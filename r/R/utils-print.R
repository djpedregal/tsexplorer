# Text output helpers used by the print() methods.

# Format a numeric matrix/data.frame as a character table.
# digits: decimals of each column (recycled); NA printed as "NA".
tsx_format_table <- function(x, digits = 4, row_names = NULL, col_names = NULL,
                             marks = NULL) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  if (is.null(col_names)) col_names <- names(x)
  digits <- rep_len(digits, ncol(x))
  cols <- vector("list", ncol(x))
  for (j in seq_len(ncol(x))) {
    v <- x[[j]]
    if (is.numeric(v)) {
      s <- ifelse(is.na(v), "NA",
                  ifelse(is.infinite(v), ifelse(v > 0, "Inf", "-Inf"),
                         formatC(v, format = "f", digits = digits[j])))
    } else {
      s <- as.character(v)
    }
    if (!is.null(marks) && !is.null(marks[[names(x)[j]]])) {
      s <- paste(s, marks[[names(x)[j]]])
    }
    cols[[j]] <- s
  }
  widths <- vapply(seq_len(ncol(x)), function(j) {
    max(nchar(c(col_names[j], cols[[j]])))
  }, numeric(1))
  lines <- character(nrow(x) + 1)
  rn <- NULL
  if (!is.null(row_names)) {
    rw <- max(nchar(row_names))
    rn <- c(formatC("", width = -rw), formatC(row_names, width = -rw))
  }
  head <- paste(vapply(seq_len(ncol(x)), function(j) {
    formatC(col_names[j], width = widths[j])
  }, character(1)), collapse = "  ")
  body <- vapply(seq_len(nrow(x)), function(i) {
    paste(vapply(seq_len(ncol(x)), function(j) {
      formatC(cols[[j]][i], width = widths[j])
    }, character(1)), collapse = "  ")
  }, character(1))
  lines <- c(head, body)
  if (!is.null(rn)) lines <- paste(rn, lines, sep = "  ")
  lines
}

# Horizontal axis of the time plots. 'dates' are the dates of the plotted
# rows (or NULL) and 't' their row numbers. Returns the coordinates x, the
# limits xlim (one period of margin), the axis label and a function that
# draws the axis (with dates when available; plots use xaxt = "n").
tsx_time_coords <- function(dates, t) {
  if (is.null(dates)) {
    return(list(x = t, xlim = c(t[1] - 1, t[length(t)] + 1), lab = "Samples",
                axis = function(side = 1) graphics::axis(side)))
  }
  x <- as.numeric(dates)
  dx <- if (length(x) > 1) min(diff(x)) else 1
  list(x = x, xlim = c(x[1] - dx, x[length(x)] + dx), lab = "Time",
       axis = function(side = 1) tsx_time_axis(dates, side))
}

# Axis with dates (Date, POSIXct or numeric times).
tsx_time_axis <- function(dates, side = 1) {
  if (inherits(dates, "Date")) {
    graphics::axis.Date(side, x = dates)
  } else if (inherits(dates, "POSIXct")) {
    graphics::axis.POSIXct(side, x = dates)
  } else {
    graphics::axis(side)
  }
  invisible()
}

# Print a block of text lines: title lines, a ruled table and notes.
tsx_cat_block <- function(title = NULL, notes = NULL, table = NULL) {
  width <- max(nchar(c(title, notes, table, "")), 40)
  rule <- strrep("-", width)
  out <- rule
  if (length(title)) out <- c(out, title, rule)
  if (length(notes)) out <- c(out, notes, rule)
  if (length(table)) out <- c(out, table[1], rule, table[-1], rule)
  cat(out, sep = "\n")
  invisible(out)
}

# Has the object a print() / plot() method of its own?
tsx_has_method <- function(generic, x) {
  !is.null(utils::getS3method(generic, class(x)[1], optional = TRUE))
}

# Default of the argument 'window' of the print() methods: TRUE in
# interactive sessions (unless options(tsexplorer.window = FALSE)).
tsx_window_default <- function() {
  isTRUE(getOption("tsexplorer.window", interactive()))
}

# Output of print() in windows. With window = TRUE (the default in
# interactive sessions, so that a call such as vident(y) at the console
# uses it) the text goes to the text window and the plot (if the class has
# one) to the graphics window: those of tooltest() for its tools and those
# of toolforecast() for faccuracy(), fcompare() and fplot(), the windows of
# the interface itself if it is open (see tsx_tk_output_window()). If Tk
# is not available, the text goes to the console and the plot to the
# current graphics device. Returns TRUE when the output has been sent, so
# that the print() method returns; with window = FALSE (scripts, tests,
# documents and the GUIs themselves) it returns FALSE and the method prints
# the text at the console.
tsx_print_window <- function(x, window, ...) {
  if (!isTRUE(window)) return(FALSE)
  draw <- tsx_has_method("plot", x)
  # objects with only a plot (plotband, fplot) have no text output
  text <- if (draw && !tsx_has_method("print", x)) NULL
          else utils::capture.output(print(x, window = FALSE, ...))
  heading <- paste0(sub("^tsx_", "", class(x)[1]),
                    if (length(x$series)) paste0("   [Series: ", paste(x$series, collapse = " - "), "]"))
  ok <- isTRUE(capabilities("tcltk")) && requireNamespace("tcltk", quietly = TRUE) &&
    !inherits(tryCatch(tsx_tk_show(x, text, heading, draw), error = function(e) e), "error")
  if (!ok) {
    if (!is.null(text)) cat(text, sep = "
")
    if (draw) graphics::plot(x)
  }
  TRUE
}

#' @export
print.tsx_result <- function(x, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window)) return(invisible(x))
  cat("<", class(x)[1], ">
", sep = "")
  utils::str(unclass(x), max.level = 1, give.attr = FALSE)
  invisible(x)
}

#' @export
plot.tsx_result <- function(x, ...) {
  message("No plot available for objects of class ", class(x)[1], ".")
  invisible(x)
}
