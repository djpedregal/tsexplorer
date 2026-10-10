# Inputs with dates: ts, zoo, xts and data.frame with a date column.

dates_m <- function() seq(as.Date("1949-01-01"), by = "month", length.out = 144)

test_that("as_tsx_matrix reads the dates of every type of input", {
  d <- dates_m()
  x <- as.vector(airpas)
  # ts: Date for frequencies 1, 4 and 12, numeric time otherwise
  expect_equal(attr(as_tsx_matrix(airpas), "dates"), d)
  q <- ts(1:8, start = c(2000, 2), frequency = 4)
  expect_equal(attr(as_tsx_matrix(q), "dates"),
               as.Date(c("2000-04-01", "2000-07-01", "2000-10-01", "2001-01-01",
                         "2001-04-01", "2001-07-01", "2001-10-01", "2002-01-01")))
  expect_equal(attr(as_tsx_matrix(ts(1:5, start = 1990)), "dates"),
               as.Date(sprintf("%d-01-01", 1990:1994)))
  w <- ts(1:10, start = c(1, 1), frequency = 7)
  expect_equal(attr(as_tsx_matrix(w), "dates"), as.numeric(time(w)))
  # data.frame with a date column (anywhere) and without
  df <- data.frame(a = x, date = d, b = 2 * x)
  m <- as_tsx_matrix(df)
  expect_equal(colnames(m), c("a", "b"))
  expect_equal(attr(m, "dates"), d)
  expect_null(attr(as_tsx_matrix(data.frame(a = x)), "dates"))
  # POSIXct
  tt <- as.POSIXct("2024-01-01 00:00", tz = "UTC") + 3600 * (0:9)
  expect_equal(attr(as_tsx_matrix(data.frame(t = tt, v = 1:10)), "dates"), tt)
  # matrices returned by as_tsx_matrix keep their dates
  expect_equal(attr(as_tsx_matrix(m), "dates"), d)
  # trimming of missing values at the ends trims the dates
  df2 <- data.frame(date = d[1:6], v = c(NA, NA, 1, 2, 3, NA))
  m2 <- as_tsx_matrix(df2)
  expect_equal(attr(m2, "dates"), d[3:5])
  expect_equal(as.vector(m2), 1:3)
  # errors
  expect_error(as_tsx_matrix(data.frame(d1 = d, d2 = d, v = x)), "more than one date")
  expect_error(as_tsx_matrix(data.frame(date = rev(d), v = x)), "increasing")
  expect_error(as_tsx_matrix(data.frame(date = d, v = x, s = "a")), "numeric")
})

test_that("zoo and xts inputs", {
  testthat::skip_if_not_installed("zoo")
  testthat::skip_if_not_installed("xts")
  d <- dates_m()
  x <- as.vector(airpas)
  z <- zoo::zoo(cbind(a = x, b = 2 * x), d)
  m <- as_tsx_matrix(z)
  expect_equal(colnames(m), c("a", "b"))
  expect_equal(attr(m, "dates"), d)
  xt <- xts::xts(x, d)
  expect_equal(attr(as_tsx_matrix(xt), "dates"), d)
  expect_equal(as.vector(as_tsx_matrix(xt)), x)
  # zoo with a yearmon index: numeric dates
  zy <- zoo::zoo(x, zoo::as.yearmon(1949 + (0:143) / 12))
  expect_equal(attr(as_tsx_matrix(zy), "dates"), 1949 + (0:143) / 12)
  # the results of the tools do not depend on the type of input
  expect_equal(vident(zoo::zoo(x, d))$table, vident(x)$table)
  expect_equal(adftest(xt, lags = 1:2)$table, adftest(x, lags = 1:2)$table)
})

test_that("time plots keep the dates of the data", {
  d <- dates_m()
  df <- data.frame(date = d, y = as.vector(airpas))
  p <- plotband(df)
  expect_equal(p$dates, d)
  expect_equal(plotband(df, subsample = 2)$dates, d[13:24])
  expect_null(plotband(df, overlay = TRUE)$dates)
  expect_null(plotband(as.vector(airpas))$dates)
  expect_equal(vcusum(df)$dates, d)
  expect_equal(vboxplot(df)$group_dates, d[seq(1, 144, by = 12)])
  expect_null(vboxplot(as.vector(airpas))$group_dates)
  out <- capture.output(print(vboxplot(df)))
  expect_true(any(grepl("1950-01", out)))
  out <- capture.output(print(vcusum(df)))
  expect_true(any(grepl("1960-12", out)))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  for (obj in list(p, plotband(df, subsample = 3), plotband(df, overlay = TRUE),
                   plotband(cbind(df, z = 2 * df$y), series = "all"), vcusum(df),
                   vboxplot(df, highlight = 3), plotband(airpas), vcusum(airpas))) {
    expect_silent(plot(obj))
  }
  # date-time axis
  tt <- as.POSIXct("2024-01-01 00:00", tz = "UTC") + 3600 * (0:47)
  expect_silent(plot(plotband(data.frame(t = tt, v = sin(1:48)), s = 24)))
})

test_that("tooltest runs every tool with dated data", {
  d <- dates_m()
  df <- data.frame(date = d, a = as.vector(log(airpas)), b = as.vector(airpas))
  y <- as_tsx_matrix(df)
  st <- tsexplorer:::tsx_tk_tooltest_state(y, tooltest_defaults(y))
  grDevices::pdf(NULL)
  st$dev <- grDevices::dev.cur()
  st$own_dev <- FALSE
  on.exit(grDevices::dev.off(st$dev))
  for (tool in names(st$tools)) {
    st$actions$set_tool(tool)
    expect_false(inherits(st$result, "error"), label = paste(tool, "result"))
  }
  st$actions$set_tool("plotband")
  expect_equal(st$result$dates, d)
})

test_that("forecasts with dates: same type required and alignment by dates", {
  testthat::skip_if_not_installed("zoo")
  testthat::skip_if_not_installed("xts")
  d <- dates_m()
  y <- as.vector(log(airpas))
  f <- ref_input("sim_fc.csv")
  dfut <- seq(as.Date("1961-01-01"), by = "month", length.out = 12)
  d60 <- d[133:144]
  # data.frame
  ydf <- data.frame(date = d, y = y)
  r <- faccuracy(ydf, data.frame(date = d60, f))
  expect_equal(r$table, faccuracy(y, f)$table)
  expect_equal(r$dates, d60)
  expect_equal(r$by_horizon$date[1:12], d60)
  expect_true(any(grepl("Forecasting period: 1960-01 to 1960-12", capture.output(print(r)))))
  cmp <- fcompare(ydf, data.frame(date = d60, f))
  expect_equal(cmp$table, fcompare(y, f)$table)
  expect_true(any(grepl("Forecasting period", capture.output(print(cmp)))))
  # zoo and xts, partial overlap (1960-07 to 1961-06)
  dmid <- seq(as.Date("1960-07-01"), by = "month", length.out = 12)
  rz <- faccuracy(zoo::zoo(y, d), zoo::zoo(f, dmid))
  expect_equal(rz$call$origin, 138)
  expect_equal(rz$table$n, rep(6, 3))
  rx <- faccuracy(xts::xts(y, d), xts::xts(f, dmid))
  expect_equal(rx$table, rz$table)
  # forecasts after the data: plot with dates, no tables
  p <- fplot(xts::xts(y, d), xts::xts(f, dfut), forecast = "all")
  expect_equal(p$origin, 144)
  expect_equal(p$dates, c(d, dfut))
  expect_error(faccuracy(xts::xts(y, d), xts::xts(f, dfut)), class = "tsx_no_overlap")
  tabs <- tsexplorer:::tsx_fgui_tables(xts::xts(y, d), xts::xts(f, dfut), NULL, 0, 1, 1, 0.95,
                                       NULL, 3)
  txt <- tsexplorer:::tsx_fgui_text(tabs, "all")
  expect_true(any(grepl(paste("Forecasting period:", format(dfut[1], "%Y-%m")), txt)))
  expect_true(any(grepl(format(dfut[12], "%Y-%m"), txt)))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  expect_silent(plot(p))
  expect_silent(plot(fplot(xts::xts(y, d), xts::xts(f, dfut), forecast = 2, subsample = 13)))
  # standard deviations: same type as the forecasts or without dates
  sd <- 0.05 * sqrt(1:12)
  b1 <- fplot(ydf, data.frame(date = d60, f1 = f[, 1]), sd)
  b2 <- fplot(ydf, data.frame(date = d60, f1 = f[, 1]), data.frame(date = d60, sd = sd))
  expect_equal(unname(b1$lower), unname(b2$lower))
  expect_equal(b1$upper[133:144, 1], f[, 1] + stats::qnorm(0.975) * sd)
  # different types
  expect_error(faccuracy(ydf, f), "same type")
  expect_error(faccuracy(y, data.frame(date = d60, f)), "same type")
  expect_error(faccuracy(zoo::zoo(y, d), xts::xts(f, d60)), "same type")
  expect_error(faccuracy(log(airpas), zoo::zoo(f, d60)), "same type")
  expect_error(fplot(ydf, data.frame(date = d60, f1 = f[, 1]), zoo::zoo(sd, d60)),
               "same type as 'py'")
  expect_error(toolforecast(ydf, f), "same type")
  # different kinds of dates
  expect_error(faccuracy(ydf, data.frame(date = as.POSIXct(d60), f)), "different kinds")
})

test_that("toolforecast tables show the dates", {
  d <- dates_m()
  y <- data.frame(date = d, y = as.vector(log(airpas)))
  f <- ref_input("sim_fc.csv")
  py <- data.frame(date = d[133:144], f)
  tabs <- tsexplorer:::tsx_fgui_tables(y, py, NULL, 0, 1, 1, 0.95, NULL, 3)
  one <- tsexplorer:::tsx_fgui_text(tabs, 1)
  expect_true(any(grepl("date", one)))
  expect_true(any(grepl("1960-03", one)))
  expect_true(any(grepl("Forecasting period", one)))
  all <- tsexplorer:::tsx_fgui_text(tabs, "all")
  expect_true(sum(grepl("Forecasting period: 1960-01 to 1960-12", all)) >= 2)
  # tcltk state with dated inputs
  a <- tsexplorer:::tsx_forecast_align(y, py, NULL, 0, NULL)
  st <- tsexplorer:::tsx_tk_toolforecast_state(y, py, NULL, 0, NULL, a)
  grDevices::pdf(NULL)
  st$dev <- grDevices::dev.cur()
  st$own_dev <- FALSE
  on.exit(grDevices::dev.off(st$dev))
  st$refresh()
  expect_equal(st$result$dates, d)
  st$actions$set_forecast("all")
  expect_false(inherits(st$result, "error"))
})
