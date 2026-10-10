#' Information criteria of AR and VAR models
#'
#' Corrected Akaike (AICc), Schwarz (SBC) and Hannan-Quinn (HQC) information
#' criteria of AR (one series) or VAR (several series) models of orders
#' `0:ncoef`, and the likelihood ratio test of each order against the
#' previous one.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param ncoef Maximum order. Default `min(38, ceiling(T / 4 / m * 2))`,
#'   limited to `T - 3`.
#' @param series Series to analyse: one series (index or name) for AR
#'   models, several or `"all"` for a VAR model.
#' @param names Optional names of the series.
#' @return An object of class `tsx_varsbc` with fields `call`, `series`
#'   (series analysed), `table` (data.frame with columns `lag`, `aicc`, `sbc`,
#'   `hqc`, `chi`, `p_chi`) and `best` (order minimising each criterion).
#' @references
#' Lütkepohl, H. (2005). *New Introduction to Multiple Time Series Analysis*.
#' Springer.
#' @examples
#' r <- varsbc(vdif(log(airpas), c(1, 1), c(1, 12)), ncoef = 15)
#' r
#' plot(r)
#' @export
varsbc <- function(y, ncoef = NULL, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  m <- ncol(y)
  if (is.null(ncoef)) ncoef <- min(38, ceiling(n / 4 / m * 2))
  ncoef <- min(tsx_check_int(ncoef, "ncoef", 0), n - 3)
  sel <- tsx_series_index(series, y, allow_all = TRUE)
  k <- length(sel)
  zm <- sweep(y[, sel, drop = FALSE], 2, colMeans(y[, sel, drop = FALSE], na.rm = TRUE), "-")
  det_sa <- det(crossprod(zm) / n)
  tab <- data.frame(lag = 0:ncoef, aicc = NA_real_, sbc = NA_real_, hqc = NA_real_,
                    chi = NA_real_, p_chi = NA_real_)
  for (i in 0:ncoef) {
    a <- tsx_auxvarsbc(zm, i)
    tab$aicc[i + 1] <- a$aicc
    tab$sbc[i + 1] <- a$sbc
    tab$hqc[i + 1] <- a$hqc
    det_s <- det(a$sigma)
    tab$chi[i + 1] <- -(n - i - 1 - 0.5 - k * i) * log(det_s / det_sa)
    det_sa <- det_s
  }
  tab$p_chi <- stats::pchisq(tab$chi, k * k, lower.tail = FALSE)
  tab$chi[1] <- NA_real_
  tab$p_chi[1] <- NA_real_
  best <- c(aicc = which.min(tab$aicc) - 1, sbc = which.min(tab$sbc) - 1,
            hqc = which.min(tab$hqc) - 1)
  tsx_result("varsbc", call = list(ncoef = ncoef, series = sel),
             series = colnames(y)[sel], table = tab, best = best)
}

tsx_series_label <- function(series) {
  if (length(series) > 1) paste0(paste(series, collapse = ", "), " (VAR model)") else series
}

#' @export
print.tsx_varsbc <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  b <- x$best
  tsx_cat_block(
    title = c("Identification Criteria", paste("Series", tsx_series_label(x$series))),
    notes = c(paste0("AICc(", b[["aicc"]], "): Corrected Akaike Information Criterion"),
              paste0("SBC(", b[["sbc"]], "): Schwarz Information Criterion"),
              paste0("HQC(", b[["hqc"]], "): Hannan and Quinn Criterion"),
              "CHI: Likelihood ratio test of order k vs order k-1"),
    table = tsx_format_table(x$table, c(0, rep(digits, 5)),
                             col_names = c("Lag", "AICc", "SBC", "HQC", "CHI", "P-CHI")))
  invisible(x)
}

#' @export
plot.tsx_varsbc <- function(x, ...) {
  t <- x$table
  b <- x$best
  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op))
  graphics::layout(matrix(1:2), heights = c(3, 1))
  graphics::par(mar = c(1, 4, 3, 1))
  graphics::matplot(t$lag, t[, c("aicc", "sbc", "hqc")], type = "b", pch = 8, lty = 1,
                    col = c("blue", "darkgreen", "red"), xaxt = "n", xlab = "",
                    ylab = "Information Criteria",
                    main = paste0("Series ", tsx_series_label(x$series),
                                  ": Information Criteria of AR Models"))
  graphics::grid(nx = NA, ny = NULL)
  graphics::legend("topright", c(paste0("AICc(", b[["aicc"]], ")"), paste0("SBC(", b[["sbc"]], ")"),
                                 paste0("HQC(", b[["hqc"]], ")")),
                   col = c("blue", "darkgreen", "red"), lty = 1, pch = 8, bty = "n")
  graphics::par(mar = c(4, 4, 0.5, 1))
  ymax <- if (all(t$p_chi > 0.3, na.rm = TRUE)) max(t$p_chi, na.rm = TRUE) else 0.3
  graphics::plot(t$lag, t$p_chi, type = "b", pch = 8, ylim = c(0, ymax), xlab = "lags",
                 ylab = "P-Chi")
  graphics::abline(h = 0.05, col = "red", lty = 3)
  graphics::abline(h = 0.1, col = "blue", lty = 3)
  invisible(x)
}

#' Non-linearity test based on the Schwarz criterion of squares
#'
#' Schwarz information criterion of AR models of orders `0:ncoef` fitted to
#' the squares of the series. A minimum at order 0 suggests linearity.
#'
#' @inheritParams varsbc
#' @param ncoef Maximum order. Default `min(38, ceiling(sqrt(T)))`, limited to
#'   `T - 3`.
#' @param series Series to analyse (index or name).
#' @return An object of class `tsx_varsbc2` with fields `call`, `series`,
#'   `table` (data.frame with columns `lag` and `sbc`), `best` (order with
#'   minimum SBC) and `linear` (`TRUE` when `best` is 0).
#' @examples
#' plot(varsbc2(vdif(log(airpas), c(1, 1), c(1, 12))))
#' @export
varsbc2 <- function(y, ncoef = NULL, series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  n <- nrow(y)
  if (is.null(ncoef)) ncoef <- min(38, ceiling(sqrt(n)))
  ncoef <- min(tsx_check_int(ncoef, "ncoef", 0), n - 3)
  i <- tsx_series_index(series, y)[1]
  z2 <- y[, i]^2
  zm <- matrix(z2 - mean(z2, na.rm = TRUE), ncol = 1)
  sbc <- vapply(0:ncoef, function(k) tsx_auxvarsbc(zm, k)$sbc, numeric(1))
  best <- which.min(sbc) - 1
  tsx_result("varsbc2", call = list(ncoef = ncoef, series = i), series = colnames(y)[i],
             table = data.frame(lag = 0:ncoef, sbc = sbc), best = best,
             linear = best == 0)
}

#' @export
print.tsx_varsbc2 <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(
    title = c("SBC Criterion of Squared Data", paste("Series", x$series)),
    notes = paste0("Minimum at lag ", x$best, ": Process is ",
                   if (x$linear) "Linear" else "Non-Linear"),
    table = tsx_format_table(x$table, c(0, digits), col_names = c("Lag", "SBC")))
  invisible(x)
}

#' @export
plot.tsx_varsbc2 <- function(x, ...) {
  t <- x$table
  graphics::plot(t$lag, t$sbc, type = "b", pch = 8, col = "blue", xlab = "lags", ylab = "SBC",
                 main = paste0("Series ", x$series, ": SBC Criterion of Squared data (Min is ",
                               x$best, ": Process is ",
                               if (x$linear) "Linear)" else "Non-Linear)"))
  graphics::grid(nx = NA, ny = NULL)
  invisible(x)
}
