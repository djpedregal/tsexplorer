#' Granger causality tests
#'
#' Wald tests (F and chi-squared versions) of Granger non-causality on a VAR
#' model without constant estimated on the demeaned series.
#'
#' Each test is written with letters for the series (`a` is the first one,
#' `b` the second, ...): the letters before `-` are the equations and the
#' letters after `-` the possibly causing variables. For instance `"a-b"`
#' tests whether `b` causes `a`, and `"ab-c"` whether `c` causes `a` and `b`.
#'
#' @param y Time series data (see [as_tsx_matrix()]), at least two series.
#' @param lags Lags of the VAR model (block constraints are possible, e.g.
#'   `c(1, 2, 12)`). Default `1:min(floor(sqrt(T)), 20)`. If the largest lag
#'   exceeds `T / 2`, `1:2` is used.
#' @param tests Character vector of tests (or a single blank-separated
#'   string). Default: every pair of series in both directions. Invalid tests
#'   are ignored.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vgranger` with fields `call`, `series` and
#'   `table`, a data.frame with columns `test`, `h0`, `constraints`, `f`,
#'   `p_f`, `chi2`, `p_chi2`.
#' @references
#' Granger, C.W.J. (1969). Investigating causal relations by econometric
#' models and cross-spectral methods. *Econometrica*, 37, 424-438.
#' @examples
#' vgranger(vdif(log(lydia_pinkham)), lags = 1:3)
#' @export
vgranger <- function(y, lags = NULL, tests = NULL, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  if (m < 2) stop("'vgranger' needs at least two series.", call. = FALSE)
  if (is.null(lags) || length(lags) == 0) lags <- seq_len(min(floor(sqrt(n)), 20))
  lags <- as.integer(round(lags))
  if (max(lags) > n / 2) lags <- 1:2
  nlags <- length(lags)
  tests <- tsx_granger_tests(tests, m)
  z <- sweep(y, 2, colMeans(y, na.rm = TRUE), "-")
  v <- tsx_mvar(z, lags, const = FALSE)
  beta <- as.vector(t(-v$p))
  vbeta <- kronecker(v$inv_xx, v$sigma)
  npar <- m * m * nlags
  tab <- data.frame(test = tests, h0 = NA_character_, constraints = NA_real_,
                    f = NA_real_, p_f = NA_real_, chi2 = NA_real_, p_chi2 = NA_real_,
                    stringsAsFactors = FALSE)
  for (k in seq_along(tests)) {
    parts <- strsplit(tests[k], "-", fixed = TRUE)[[1]]
    eqs <- utf8ToInt(parts[1]) - 96L
    causes <- utf8ToInt(parts[2]) - 96L
    nconst <- length(causes) * length(eqs) * nlags
    cm <- matrix(0, nconst, npar)
    r <- 1
    for (ci in causes) {
      for (ei in eqs) {
        for (l in seq_len(nlags)) {
          cm[r, (ci - 1) * m + ei + (l - 1) * m * m] <- 1
          r <- r + 1
        }
      }
    }
    cb <- cm %*% beta
    w <- drop(t(cb) %*% solve(cm %*% vbeta %*% t(cm)) %*% cb)
    df2 <- n * m - npar + m * m
    tab$constraints[k] <- nconst
    tab$f[k] <- w / nconst
    tab$p_f[k] <- stats::pf(w / nconst, nconst, df2, lower.tail = FALSE)
    tab$chi2[k] <- w
    tab$p_chi2[k] <- stats::pchisq(w, nconst, lower.tail = FALSE)
    tab$h0[k] <- paste(tsx_and_list(colnames(y)[causes]),
                       if (length(causes) > 1) "do" else "does", "not cause",
                       tsx_and_list(colnames(y)[eqs]))
  }
  tsx_result("vgranger", call = list(lags = lags, tests = tests), series = colnames(y),
             table = tab)
}

tsx_and_list <- function(x) {
  if (length(x) == 1) return(x)
  paste(paste(x[-length(x)], collapse = ", "), "and", x[length(x)])
}

# Default and validation of Granger tests.
tsx_granger_tests <- function(tests, m) {
  t1 <- rep(1:m, m)
  t2 <- rep(1:m, each = m)
  keep <- t1 != t2
  def <- paste0(letters[t1[keep]], "-", letters[t2[keep]])
  if (is.null(tests) || length(tests) == 0) return(def)
  if (length(tests) == 1) tests <- strsplit(trimws(tests), "[[:space:]]+")[[1]]
  tests <- tolower(gsub("[[:space:]]", "", tests))
  ok <- vapply(tests, function(ti) {
    if (!grepl("^[a-z]+-[a-z]+$", ti)) return(FALSE)
    let <- utf8ToInt(gsub("-", "", ti)) - 96L
    all(let >= 1 & let <= m) && !anyDuplicated(let)
  }, logical(1))
  tests <- tests[ok]
  if (length(tests) == 0) def else unname(tests)
}

#' @export
print.tsx_vgranger <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  lags <- x$call$lags
  const <- if (max(lags) == length(lags)) "" else "CONSTRAINED "
  tsx_cat_block(
    title = c("Granger Causality Tests",
              paste0("Based on a ", const, "VAR(", max(lags), ") model")),
    table = tsx_format_table(x$table[, c("constraints", "f", "p_f", "chi2", "p_chi2")],
                             c(0, rep(digits, 4)), row_names = x$table$h0,
                             col_names = c("Constraints", "F-Stat", "P-value", "Chi-stat",
                                           "P-value")))
  invisible(x)
}
