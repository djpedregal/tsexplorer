#' Box-Cox transformation
#'
#' Estimates the Box-Cox parameter \eqn{\lambda} of each series with the
#' method of Guerrero (1993): the series is divided into groups of `group`
#' consecutive observations and \eqn{\lambda} minimises the coefficient of
#' variation of \eqn{s_j / \bar{z}_j^{1 - \lambda}} (standard deviation over
#' mean of each group). It also evaluates, over a grid of values of
#' \eqn{\lambda} (`axislambdas`), the standard deviation, the mean over
#' standard deviation and the criterion of the transformed series, and
#' returns the transformed data.
#'
#' Series with non-positive values are shifted by `abs(min) + 1e-4` before
#' the transformation.
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param lambdas Optional values of \eqn{\lambda} for the transformation of
#'   each series (the last one is repeated for the remaining series). If
#'   `NULL` they are estimated.
#' @param group Number of observations per group (usually the seasonal
#'   period). Default 12.
#' @param axislambdas Grid of \eqn{\lambda} values for the plot.
#' @param series Series used for the grid evaluation and the plot.
#' @param names Optional names of the series.
#' @return An object of class `tsx_vboxcox` with fields `call`, `series`,
#'   `lambdas` (estimated or supplied, one per series), `estimated` (logical),
#'   `transformed` (matrix of transformed series) and `grid`, a data.frame for
#'   the selected series with columns `lambda`, `sd`, `mean_sd`, `criterion`
#'   (minus the coefficient of variation), and their standardised versions
#'   `sd_std`, `mean_sd_std`, `criterion_std` (as plotted).
#' @references
#' Box, G.E.P. and Cox, D.R. (1964). An analysis of transformations.
#' *Journal of the Royal Statistical Society B*, 26, 211-252.
#'
#' Guerrero, V.M. (1993). Time-series analysis supported by power
#' transformations. *Journal of Forecasting*, 12, 37-48.
#' @examples
#' r <- vboxcox(airpas)
#' r$lambdas
#' plot(r)
#' @export
vboxcox <- function(y, lambdas = NULL, group = 12, axislambdas = seq(-1, 1, by = 0.1),
                    series = 1, names = NULL) {
  y <- as_tsx_matrix(y, names)
  m <- ncol(y)
  group <- tsx_check_int(group, "group", 2)
  shifted <- apply(y, 2, tsx_boxcox_shift)
  shifted <- matrix(shifted, ncol = m)
  estimated <- is.null(lambdas) || length(lambdas) == 0
  if (estimated) {
    lambdas <- vapply(seq_len(m), function(i) {
      tsx_fminsearch(function(l) tsx_guerrero(l, shifted[, i], group), 1)$par
    }, numeric(1))
  } else {
    lambdas <- as.numeric(lambdas)[seq_len(min(length(lambdas), m))]
    lambdas <- c(lambdas, rep(lambdas[length(lambdas)], m - length(lambdas)))
  }
  tr <- shifted
  for (i in seq_len(m)) tr[, i] <- tsx_boxcox(shifted[, i], lambdas[i])
  colnames(tr) <- colnames(y)
  i <- tsx_series_index(series, y)[1]
  grid <- NULL
  if (length(axislambdas) > 0) {
    zi <- shifted[, i]
    grid <- data.frame(lambda = axislambdas, sd = NA_real_, mean_sd = NA_real_,
                       criterion = NA_real_)
    for (j in seq_along(axislambdas)) {
      zt <- tsx_boxcox(zi, axislambdas[j])
      grid$sd[j] <- stats::sd(zt, na.rm = TRUE)
      grid$mean_sd[j] <- mean(zt, na.rm = TRUE) / grid$sd[j]
      grid$criterion[j] <- -tsx_guerrero(axislambdas[j], zi, group)
    }
    std <- tsx_standardize(as.matrix(grid[, c("sd", "mean_sd", "criterion")]))
    grid$sd_std <- std[, 1]
    grid$mean_sd_std <- std[, 2]
    grid$criterion_std <- std[, 3]
  }
  names(lambdas) <- colnames(y)
  tsx_result("vboxcox", call = list(group = group, axislambdas = axislambdas, series = i),
             series = colnames(y), lambdas = lambdas, estimated = estimated,
             transformed = tr, grid = grid)
}

tsx_boxcox_shift <- function(z) {
  mn <- min(z, na.rm = TRUE)
  if (mn <= 0) z <- z + abs(mn) + 1e-4
  z
}

tsx_boxcox <- function(z, lambda) {
  if (lambda == 0) log(z) else (z^lambda - 1) / lambda
}

# Guerrero (1993) criterion (coefficient of variation).
tsx_guerrero <- function(lambda, z, group) {
  n <- length(z)
  ny <- floor(n / group)
  yr <- matrix(z[(n - ny * group + 1):n], nrow = group)
  myr <- colMeans(yr, na.rm = TRUE)
  sd <- apply(yr, 2, stats::sd, na.rm = TRUE)
  yt <- sd / myr^(1 - lambda)
  stats::sd(yt, na.rm = TRUE) / mean(yt, na.rm = TRUE)
}

#' @export
print.tsx_vboxcox <- function(x, digits = 4, window = tsx_window_default(), ...) {
  if (tsx_print_window(x, window, digits = digits)) return(invisible(x))
  tsx_cat_block(
    title = if (x$estimated) "Estimation of Box-Cox Lambdas:" else "Box-Cox Lambdas:",
    table = tsx_format_table(data.frame(x$lambdas), digits, row_names = x$series,
                             col_names = "Lambdas"))
  invisible(x)
}

#' @export
plot.tsx_vboxcox <- function(x, ...) {
  g <- x$grid
  if (is.null(g)) stop("No grid of lambdas to plot.", call. = FALSE)
  v <- as.matrix(g[, c("sd_std", "mean_sd_std", "criterion_std")])
  opt <- c(which.min(v[, 1]), which.min(v[, 2]), which.max(v[, 3]))
  ylim <- range(v, na.rm = TRUE) + c(-0.1, 0.1)
  graphics::matplot(g$lambda, v, type = "b", pch = 8, lty = 1, col = c("blue", "red", "black"),
                    xlim = range(g$lambda) + c(-0.1, 0.1), ylim = ylim, xlab = "Lambda",
                    ylab = "Normalised S.D., Mean/S.D. & L-Lik",
                    main = paste0("Series ", x$series[x$call$series], ": S.D.(blue; ",
                                  g$lambda[opt[1]], "), Mean/S.D.(red; ", g$lambda[opt[2]],
                                  ") & L-Lik(black; ", g$lambda[opt[3]], ")"),
                    cex.main = 0.85)
  cols <- c("blue", "red", "black")
  for (k in 1:3) {
    graphics::segments(g$lambda[opt[k]], ylim[1], g$lambda[opt[k]], v[opt[k], k],
                       col = cols[k], lty = 3)
  }
  invisible(x)
}
