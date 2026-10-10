test_that("sumstats matches the reference values", {
  s <- ref("sumstats")
  for (nm in c("airpas", "scc", "sim_na")) {
    y <- switch(nm, airpas = airpas, scc = scc, sim_na = ref_input("sim_na.csv"))
    r <- sumstats(y)
    v <- matrix(s[[nm]]$value, nrow = 22)
    # rows 7 (P(mean = 0)) and 15 (range) are checked separately
    # the mode (row 11) is not in the MATLAB output
    vals <- t(as.matrix(r$stats[, -1]))[-11, , drop = FALSE]
    expect_ref(vals[-c(7, 15), , drop = FALSE], v[-c(7, 15), , drop = FALSE])
    # two sided p-value (twice the one sided value)
    expect_ref(r$stats$p_mean_zero, 2 * v[7, ])
    # range is max - min
    expect_ref(r$stats$range, v[13, ] - v[3, ])
    if (!is.null(r$cor)) expect_ref(r$cor, s[[nm]]$corr)
  }
  x <- as.vector(airpas)
  expect_equal(sumstats(x - 280)$stats$p_mean_zero, stats::t.test(x - 280)$p.value)
})

test_that("sumstats: structure, one and several series, bootstrap", {
  r1 <- sumstats(airpas)
  expect_s3_class(r1, c("tsx_sumstats", "tsx_result"))
  expect_null(r1$cor)
  expect_equal(nrow(r1$stats), 1L)
  r3 <- sumstats(scc)
  expect_equal(dim(r3$cor), c(3L, 3L))
  expect_equal(r1$stats$median, stats::median(airpas))
  # mode: most frequent value, the smallest one in case of ties (MATLAB mode)
  expect_equal(sumstats(c(3, 1, 2, 2, 3, NA))$stats$mode, 2)
  expect_equal(sumstats(c(5, 4, 4, 5, 9))$stats$mode, 4)
  expect_equal(sumstats(c(2.5, 1.5, 3))$stats$mode, 1.5)
  expect_output(print(r1), "Mode:")
  b1 <- sumstats(airpas, gaussian = FALSE, nsimul = 200, seed = 1)
  b2 <- sumstats(airpas, gaussian = FALSE, nsimul = 200, seed = 1)
  expect_equal(b1$stats$p_mean_zero, b2$stats$p_mean_zero)
  expect_true(b1$stats$p_mean_zero >= 0 && b1$stats$p_mean_zero <= 1)
  expect_output(print(r3), "Kurtosis")
})

test_that("gausstest matches the reference values", {
  g <- ref("gausstest")
  for (nm in c("dla", "scc", "nile")) {
    y <- switch(nm, dla = dla(), scc = scc, nile = nile)
    r <- gausstest(y)
    expect_ref(cbind(r$table$skewness, r$table$kurtosis), cbind(g[[nm]]$skew, g[[nm]]$kurto))
    expect_ref(cbind(r$table$bj, r$table$p_bj), cbind(g[[nm]]$beraj, g[[nm]]$pvalue))
    # Kolmogorov-Smirnov statistic max(D+, D-) (reference 'D_full').
    expect_ref(cbind(r$table$ksl, r$table$p_ksl), cbind(g[[nm]]$D_full, g[[nm]]$Dc_full))
  }
  r <- gausstest(scc)
  expect_ref(c(r$bj_multi, r$p_bj_multi), c(g$scc$vBJ, g$scc$PvBJ))
})

test_that("gausstest with missing values uses the number of observations", {
  # The Bera-Jarque statistic uses the number of non missing observations.
  g <- ref("gausstest")
  sn <- ref_input("sim_na.csv")
  r <- gausstest(sn)
  n <- sum(!is.na(sn))
  expect_equal(r$table$n, n)
  expect_ref(r$table$bj, g$sim_na$beraj * n / g$sim_na$T)
  # KS statistic is the classical one (agrees with stats::ks.test)
  x <- as.vector(dla())
  d <- suppressWarnings(stats::ks.test(x, "pnorm", mean(x), sd(x))$statistic)
  expect_equal(gausstest(x)$table$ksl, unname(d))
})

test_that("vhist and vqqplot return the plotted data", {
  h <- vhist(dla(), bins = 10)
  expect_equal(sum(h$hist$count), length(dla()))
  expect_equal(nrow(h$density), 181L)
  q <- vqqplot(dla())
  gr <- ref("graphics")
  expect_ref(cbind(q$table$theoretical, q$table$empirical), cbind(gr$vqqplot_dla$qtheo, gr$vqqplot_dla$zi))
  # reference line through the quartiles of the data
  expect_ref(q$line$y, c(gr$vqqplot_dla$yini_fixed, gr$vqqplot_dla$yend_fixed))
  # missing values are dropped before computing the plotting positions
  sn <- ref_input("sim_na.csv")
  expect_equal(nrow(vqqplot(sn)$table), sum(!is.na(sn)))
})

test_that("boxplots, stdmean and vcusum match the reference values", {
  gr <- ref("graphics")
  expect_ref(as.matrix(vboxplot(airpas)$stats[, -1]), gr$boxplot_a$box)
  r <- vtboxplot(airpas)
  expect_ref(as.matrix(r$stats[, -1]), gr$boxplot_a$tbox)
  expect_ref(r$data, gr$boxplot_a$tdata)
  for (k in 0:2) {
    r <- stdmean(airpas, 12, k)
    x <- gr[[paste0("stdmean_a", k)]]
    expect_ref(cbind(r$table$location, r$table$dispersion), x$data)
    expect_ref(r$coef, x$beta)
  }
  r <- vcusum(dla())
  expect_ref(with(r$table, cbind(cusum, cusumsq, cusum_upper, cusumsq_lower, cusumsq_upper)),
             with(gr$vcusum_dla, cbind(cusum, cusumsq, band, bandsq)))
})

test_that("plotband and vscatter return the plotted data", {
  p <- plotband(airpas, s = 12, subsample = 2)
  expect_equal(p$time, 13:24)
  expect_equal(as.vector(p$data), as.vector(airpas)[13:24])
  expect_equal(p$mean, mean(airpas))
  o <- plotband(airpas, overlay = TRUE)
  expect_equal(dim(o$data), c(12L, 12L))
  a <- plotband(scc, series = "all", standard = TRUE)
  expect_equal(ncol(a$data), 3L)
  v <- vscatter(scc)
  expect_equal(nrow(v$coef), 6L)
  b <- v$coef[v$coef$x == "y1" & v$coef$y == "y2", ]
  expect_equal(c(b$intercept, b$slope), unname(stats::coef(stats::lm(scc[, 2] ~ scc[, 1]))))
})
