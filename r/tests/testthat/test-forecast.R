fc <- function() ref_input("sim_fc.csv")

test_that("faccuracy matches the reference values", {
  fo <- ref("forecast")
  r <- faccuracy(lav(), fc())
  expect_equal(r$call$origin, 132)
  # columns N, ME (bias), MAE and MASE of the reference
  expect_ref(as.matrix(r$table[, c("n", "bias", "mae", "mase")]), fo$trunc1$accuracy[, 1:4])
  h <- r$by_horizon[r$by_horizon$forecast == 1, ]
  expect_ref(as.matrix(h[, c("bias", "mae", "mase")]), fo$trunc1$horizon1[, 1:3])
})

test_that("comparison tests match the reference values", {
  # the reference values are computed with percentage error losses
  fo <- ref("forecast")
  act <- as.vector(lav())[133:144]
  pe <- (fc() - act) / act
  for (tr in 1:2) {
    tab <- tsexplorer:::tsx_compare_losses(list(mspe = pe^2, mape = abs(pe)), tr, 12)
    x <- fo[[paste0("trunc", tr)]]
    ms <- tab[tab$loss == "mspe", ]
    ma <- tab[tab$loss == "mape", ]
    expect_ref(as.matrix(ms[, c("sign", "p_sign", "wilcoxon", "p_wilcoxon")]), x$mspe[, 3:6])
    expect_ref(as.matrix(ma[, c("sign", "p_sign", "wilcoxon", "p_wilcoxon")]), x$mape[, 3:6])
    # long run variance with the autocovariances of lags 1..trunc
    expect_ref(cbind(ms$dm, ms$p_dm, ma$dm, ma$p_dm), x$dm_fixed)
  }
})

test_that("fcompare uses squared and absolute errors", {
  act <- as.vector(lav())[133:144]
  f <- fc()
  e <- f - act
  for (tr in 1:2) {
    r <- fcompare(lav(), f, trunc = tr)
    expect_equal(unique(r$table$loss), c("mse", "mae"))
    expect_equal(r$table,
                 tsexplorer:::tsx_compare_losses(list(mse = e^2, mae = abs(e)), tr, 12))
    # Diebold-Mariano computed directly
    d <- e[, 1]^2 - e[, 2]^2
    dc <- d - mean(d)
    lrv <- var(dc) + 2 * sum(vapply(seq_len(tr), function(k) sum(dc[-(1:k)] * dc[1:(12 - k)]),
                                    0)) / 12
    dm <- mean(d) / sqrt(lrv / 12)
    row <- r$table[r$table$f1 == 1 & r$table$f2 == 2 & r$table$loss == "mse", ]
    expect_equal(row$dm, dm)
    expect_equal(row$p_dm, 2 * pnorm(-abs(dm)))
  }
  # Wilcoxon (exact, no ties) and sign test computed directly
  row <- r$table[r$table$f1 == 1 & r$table$f2 == 3 & r$table$loss == "mae", ]
  w <- suppressWarnings(stats::wilcox.test(abs(e[, 1]), abs(e[, 3]), paired = TRUE,
                                           exact = TRUE))
  expect_equal(row$wilcoxon, unname(w$statistic))
  expect_equal(row$p_wilcoxon, w$p.value)
  n1 <- sum(abs(e[, 1]) > abs(e[, 3]))
  expect_equal(row$sign, (n1 - 6) / (0.5 * sqrt(12)))
  out <- capture.output(print(r))
  expect_true(any(grepl("Squared Errors", out)) && any(grepl("Absolute Errors", out)))
  expect_false(any(grepl("Percentage", out)))
})

test_that("Bias+MAE, RMSE and interval measures agree with direct computations", {
  y <- as.vector(lav())
  f <- fc()
  act <- y[133:144]
  # standard deviations of the three forecasts (growing with the horizon)
  st <- outer(sqrt(1:12), c(0.025, 0.04, 0.015))
  for (lv in c(0.95, 0.8)) {
    r <- faccuracy(lav(), f, st, level = lv)
    al <- 1 - lv
    z <- stats::qnorm(1 - al / 2)
    for (k in 1:3) {
      e <- f[, k] - act
      lo <- f[, k] - z * st[, k]
      up <- f[, k] + z * st[, k]
      tab <- r$table[k, ]
      expect_equal(tab$rmse, sqrt(mean(e^2)))
      expect_equal(tab$bias_mae, abs(mean(e)) + mean(abs(e)))
      expect_equal(tab$coverage, mean(act >= lo & act <= up))
      expect_equal(tab$range, mean(up - lo))
      mis <- mean((up - lo) + 2 / al * pmax(lo - act, 0) + 2 / al * pmax(act - up, 0))
      expect_equal(tab$mis, mis)
      pin <- function(q, tau) mean(ifelse(act >= q, tau * (act - q), (1 - tau) * (q - act)))
      expect_equal(tab$pinball_lower, pin(lo, al / 2))
      expect_equal(tab$pinball_upper, pin(up, 1 - al / 2))
      h <- r$by_horizon[r$by_horizon$forecast == k, ]
      expect_equal(h$rmse[12], tab$rmse)
      expect_equal(h$bias_mae[12], tab$bias_mae)
      expect_equal(h$bias_mae[3], abs(mean(e[1:3])) + mean(abs(e[1:3])))
      expect_equal(h$mis[12], tab$mis)
      expect_equal(h$coverage[3], mean(act[1:3] >= lo[1:3] & act[1:3] <= up[1:3]))
    }
  }
  # without intervals the interval measures are NA and not printed
  r <- faccuracy(lav(), f)
  expect_true(all(is.na(r$table[, c("coverage", "range", "mis", "pinball_lower",
                                    "pinball_upper")])))
  out <- capture.output(print(r))
  expect_false(any(grepl("coverage|mis:", out)))
  expect_true(any(grepl("rmse", out)) && any(grepl("bias+mae", out, fixed = TRUE)))
  expect_false(any(grepl("RelMAE|ME:", out)))
  expect_equal(names(r$table)[2:5], c("n", "bias", "mae", "bias_mae"))
  expect_false(any(grepl("MAPE", out)))
  out <- capture.output(print(faccuracy(lav(), f, st)))
  expect_true(any(grepl("coverage", out)) && any(grepl("pinball_upper", out)))
  expect_error(faccuracy(lav(), f, st, level = 95), "between 0 and 1")
  # standard deviations of the first forecast only: no interval measures
  # for the others
  r1 <- faccuracy(lav(), f, st[, 1])
  expect_equal(r1$table$mis[1], faccuracy(lav(), f, st)$table$mis[1])
  expect_true(all(is.na(r1$table$mis[2:3])))
  # wrong standard deviations
  expect_error(faccuracy(lav(), f, cbind(st, st)), "at most as many columns")
  expect_error(faccuracy(lav(), f, -st), "non negative")
})

test_that("bands of several series and forecasts are py -/+ z * stdpy", {
  # two series, two forecasts: columns (f1 s1, f1 s2, f2 s1, f2 s2)
  y <- cbind(a = 1:20, b = 21:40)
  py <- cbind(15:20 + 0.5, 35:40 - 0.5, 15:20 - 1, 35:40 + 1)
  sd <- cbind(rep(0.1, 6), rep(0.2, 6), rep(0.3, 6), rep(0.4, 6))
  z <- stats::qnorm(0.95)
  p <- fplot(y, py, sd, series = 2, forecast = "all", level = 0.9)
  expect_equal(p$call$level, 0.9)
  expect_equal(unname(p$lower[15:20, ]), py[, c(2, 4)] - z * sd[, c(2, 4)])
  expect_equal(unname(p$upper[15:20, ]), py[, c(2, 4)] + z * sd[, c(2, 4)])
  r <- faccuracy(y, py, sd, series = 1, level = 0.9)
  expect_equal(r$table$range, 2 * z * c(0.1, 0.3))
})

test_that("alignment of actual values and forecasts", {
  y <- lav()
  f <- fc()
  # forecasts shorter than the actual data: aligned at the end
  a <- faccuracy(y, f)
  # actual data of the forecasting period only: origin 0, no MASE
  b <- faccuracy(y[133:144], f)
  expect_equal(b$call$origin, 0)
  expect_true(all(is.na(b$table$mase)))
  expect_equal(a$table$mae, b$table$mae)
  # full length forecasts with explicit origin
  full <- rbind(matrix(NA, 132, 3), f)
  c1 <- faccuracy(y, full, origin = 132)
  expect_equal(c1$table, a$table)
})

test_that("fplot returns the plotted data", {
  y <- lav()
  f <- fc()
  p <- fplot(y, f[, 1], rep(0.05, 12))
  expect_equal(p$origin, 132)
  expect_equal(dim(p$lower), c(144L, 1L))
  expect_equal(p$upper[133:144, 1], f[, 1] + stats::qnorm(0.975) * 0.05)
  expect_equal(p$errors[133:144, 1], f[, 1] - as.vector(y)[133:144])
  p <- fplot(y, f, forecast = "all", subsample = 12)
  expect_equal(p$time, 133:144)
  expect_equal(ncol(p$forecasts), 3L)
  expect_error(fplot(y, f, forecast = 4), "forecast")
})

test_that("forecasts without overlap with the actual values: plot and forecasts table", {
  y <- lav()
  f <- fc()
  # forecasts of periods 145-156, actual values up to 144
  full <- rbind(matrix(NA, 144, 3), f)
  for (o in c(0, 144)) {
    p <- fplot(y, full, origin = o, forecast = "all")
    expect_s3_class(p, "tsx_fplot")
    expect_equal(length(p$actual), 156L)
    grDevices::pdf(NULL)
    expect_silent(plot(p))
    grDevices::dev.off()
    expect_error(faccuracy(y, full, origin = o), class = "tsx_no_overlap")
    expect_error(fcompare(y, full, origin = o), class = "tsx_no_overlap")
  }
  tabs <- tsexplorer:::tsx_fgui_tables(y, full, NULL, 144, 1, 1, 0.95, NULL, 3)
  expect_true(tabs$no_overlap)
  expect_null(tabs$accuracy)
  # table of the forecasts only (no actual values nor error measures)
  all <- tsexplorer:::tsx_fgui_text(tabs, "all")
  expect_true(any(grepl("forecasts only", all)))
  expect_true(any(grepl("F#3", all, fixed = TRUE)))
  expect_false(any(grepl("MAE|Bias|Coverage", all)))
  head <- grep("^ *t ", all, value = TRUE)
  expect_length(head, 1)
  expect_false(grepl("actual", head))
  rows <- grep("^ *14[5-9]|^ *15[0-6]", all, value = TRUE)
  expect_length(rows, 12)
  expect_match(rows[1], formatC(f[1, 3], format = "f", digits = 3), fixed = TRUE)
  one <- tsexplorer:::tsx_fgui_text(tabs, 2)
  expect_true(any(grepl("Forecast #2", one)))
  expect_false(any(grepl("lower", one)))
  # with standard deviations: bounds of the intervals of one forecast
  sd <- rbind(matrix(NA, 144, 3), matrix(0.05, 12, 3))
  tb <- tsexplorer:::tsx_fgui_tables(y, full, sd, 144, 1, 1, 0.9, NULL, 3)
  one <- tsexplorer:::tsx_fgui_text(tb, 1)
  expect_true(any(grepl("90% prediction intervals", one)))
  r1 <- grep("^ *145 ", one, value = TRUE)
  expect_match(r1, formatC(f[1, 1] + stats::qnorm(0.95) * 0.05, format = "f", digits = 3),
               fixed = TRUE)
  # partial overlap still gives tables
  part <- rbind(matrix(NA, 138, 3), f)
  expect_equal(faccuracy(y, part, origin = 138)$table$n, rep(6, 3))
  expect_false(tsexplorer:::tsx_fgui_tables(y, part, NULL, 138, 1, 1, 0.95, NULL, 3)$no_overlap)
})

test_that("ts inputs are aligned by their dates", {
  y <- log(airpas)                                    # 1949-1960, monthly
  f <- ref_input("sim_fc.csv")                        # forecasts of 1960
  # forecasts of 1960 as ts: same result as the positional alignment
  f60 <- ts(f, start = c(1960, 1), frequency = 12)
  expect_equal(faccuracy(y, f60)$table, faccuracy(as.vector(y), f)$table)
  expect_equal(fcompare(y, f60)$table, fcompare(as.vector(y), f)$table)
  # forecasts of 1961: after the end of the data, no overlap
  f61 <- ts(f, start = c(1961, 1), frequency = 12)
  p <- fplot(y, f61, forecast = "all")
  expect_equal(p$origin, 144)
  expect_equal(length(p$actual), 156L)
  expect_true(all(is.na(p$actual[145:156])))
  expect_equal(unname(p$forecasts[145:156, ]), unname(f))
  expect_equal(p$dates[c(1, 156)], as.Date(c("1949-01-01", "1961-12-01")))
  grDevices::pdf(NULL)
  expect_silent(plot(p))
  grDevices::dev.off()
  expect_error(faccuracy(y, f61), class = "tsx_no_overlap")
  # forecasts of 1960-07 to 1961-06: partial overlap of 6 periods
  fmid <- ts(f, start = c(1960, 7), frequency = 12)
  r <- faccuracy(y, fmid)
  expect_equal(r$call$origin, 138)
  expect_equal(r$table$n, rep(6, 3))
  expect_equal(r$table$bias, unname(colMeans(f[1:6, ] - as.vector(y)[139:144])))
  # forecasts starting before the data
  early <- ts(f, start = c(1948, 1), frequency = 12)
  a <- tsexplorer:::tsx_forecast_align(y, early)
  expect_equal(nrow(a$y), 156L)
  expect_equal(a$origin, 0)
  expect_equal(unname(a$y[13, 1]), as.vector(y)[1])
  # standard deviations: ts or with the rows of py
  sd <- 0.05 * sqrt(1:12)
  p1 <- fplot(y, f61[, 1], sd)
  p2 <- fplot(y, f61[, 1], ts(sd, start = c(1961, 1), frequency = 12))
  expect_equal(unname(p1$lower), unname(p2$lower))
  expect_equal(p1$upper[145:156, 1], f[, 1] + stats::qnorm(0.975) * sd)
  # errors
  expect_error(fplot(y, ts(f, start = 1961, frequency = 4)), "same frequency")
  expect_error(fplot(y, f61[, 1], sd[1:6]), "same number of rows")
  # inputs of different types
  expect_error(faccuracy(y, unclass(f61)), "same type")
})

test_that("forecast functions check their inputs", {
  expect_error(faccuracy(scc, la()[1:12]), "multiple")
  expect_error(fcompare(lav(), fc()[, 1]), "two forecasts")
})
