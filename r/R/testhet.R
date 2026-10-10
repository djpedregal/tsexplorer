#' Heteroskedasticity tests
#'
#' Variance ratio F tests between non-overlapping subsamples of each series.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param timecuts Definition of the subsamples:
#'   * a vector of `n` cut points divides the sample into `n + 1`
#'     consecutive subsamples (cut points closer than 5 observations to the
#'     ends are discarded),
#'   * a `n x 2` matrix gives the first and last observation of each
#'     subsample (overlapping or invalid rows are discarded).
#'   If no valid subsamples remain, the sample is split into three parts.
#'   Default `c(floor(T / 3), floor(2 * T / 3) + 2)`.
#' @param names Optional names of the series.
#' @return An object of class `tsx_testhet` with fields `call`, `series`,
#'   `samples` (matrix with first and last observation of each subsample) and
#'   `table`, a data.frame with columns `series`, `start1`, `end1`, `start2`,
#'   `end2`, `f` (ratio of variances, always <= 1) and `p_value` (two sided).
#' @examples
#' testhet(airpas)
#' testhet(log(airpas), c(48, 96))
#' testhet(airpas, rbind(c(1, 30), c(50, 90), c(100, 144)))
#' @export
testhet <- function(y, timecuts = NULL, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  cuts <- tsx_timecuts(timecuts, n)
  tab <- NULL
  for (s in seq_len(ncol(y))) {
    for (i in seq_len(nrow(cuts) - 1)) {
      for (j in (i + 1):nrow(cuts)) {
        zi <- y[cuts[i, 1]:cuts[i, 2], s]
        zj <- y[cuts[j, 1]:cuts[j, 2], s]
        f <- stats::var(zi, na.rm = TRUE) / stats::var(zj, na.rm = TRUE)
        d1 <- sum(!is.na(zi)) - 1
        d2 <- sum(!is.na(zj)) - 1
        if (f > 1) {
          f <- 1 / f
          tmp <- d1
          d1 <- d2
          d2 <- tmp
        }
        tab <- rbind(tab, data.frame(series = colnames(y)[s], start1 = cuts[i, 1],
                                     end1 = cuts[i, 2], start2 = cuts[j, 1],
                                     end2 = cuts[j, 2], f = f,
                                     p_value = 2 * stats::pf(f, d1, d2),
                                     stringsAsFactors = FALSE))
      }
    }
  }
  tsx_result("testhet", call = list(timecuts = timecuts), series = colnames(y),
             samples = cuts, table = tab)
}

# Subsamples of testhet (first and last observation in each row).
tsx_timecuts <- function(timecuts, n) {
  default <- function() {
    i1 <- floor(n / 3)
    i2 <- floor(2 * n / 3) + 2
    rbind(c(1, i1), c(i1 + 1, i2), c(i2 + 1, n))
  }
  if (is.null(timecuts) || length(timecuts) == 0) {
    timecuts <- c(floor(n / 3), floor(2 * n / 3) + 2)
  }
  if (is.null(dim(timecuts)) || any(dim(timecuts) == 1)) {
    tc <- sort(as.vector(timecuts))
    tc <- tc[!(tc < 5 | tc > n - 5)]
    if (length(tc) == 0) return(default())
    cuts <- cbind(c(1, tc + 1), c(tc, n))
  } else {
    cuts <- t(apply(as.matrix(timecuts), 1, sort))
    cuts <- cuts[order(cuts[, 1]), , drop = FALSE]
    drop <- c(which(cuts[-1, 1] < 5) + 1, which(cuts[, 1] > n - 5))
    if (length(drop)) cuts <- cuts[-unique(drop), , drop = FALSE]
    drop <- which(diff(cuts[, 2]) < 0) + 1
    if (length(drop)) cuts <- cuts[-drop, , drop = FALSE]
    drop <- which((cuts[-1, 1] - cuts[-nrow(cuts), 2]) < 0) + 1
    if (length(drop)) cuts <- cuts[-drop, , drop = FALSE]
  }
  if (nrow(cuts) < 2) return(default())
  storage.mode(cuts) <- "double"
  colnames(cuts) <- c("start", "end")
  cuts
}

#' @export
print.tsx_testhet <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  cat(strrep("-", 50), "\nVariance Ratio Tests\n", strrep("-", 50),
      "\nH0: Variances are the same (homoskedasticity).\n",
      "(Assumptions: Independence and Normality)\n", sep = "")
  for (s in x$series) {
    t <- x$table[x$table$series == s, ]
    rn <- paste0("Samples (", t$start1, " - ", t$end1, ") / (", t$start2, " - ", t$end2, "):")
    cat("\n")
    tsx_cat_block(title = paste0("Series ", s, ":"),
                  table = tsx_format_table(t[, c("f", "p_value")], digits, row_names = rn,
                                           col_names = c("F-Test", "P-value")))
  }
  invisible(x)
}
