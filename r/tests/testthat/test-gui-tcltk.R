# The tcltk interfaces keep their state in an environment and the widgets
# only call state$actions; the tests drive the interfaces through them. The
# plots go to a null pdf device.

null_device <- function() {
  grDevices::pdf(NULL)
  grDevices::dev.cur()
}

test_that("tcltk tooltest state gives the same calls as the Shiny version", {
  y <- as_tsx_matrix(scc)
  opts <- tooltest_defaults(y)
  st <- tsexplorer:::tsx_tk_tooltest_state(y, opts)
  st$dev <- null_device()
  st$own_dev <- FALSE
  on.exit(grDevices::dev.off(st$dev))
  st$actions$set_tool("vident")
  st$actions$set_series(2)
  expect_s3_class(st$result, "tsx_vident")
  expect_equal(st$last_call$args$series, 2L)
  expect_equal(st$result, vident(y, ncoef = opts$vident$ncoef, s = 12, npar = 0, series = 2))
  # options with linked seasonal period
  st$actions$set_options(list(ncoef = "10", s = "4", npar = "1"))
  expect_equal(st$result$call$ncoef, 10)
  expect_equal(st$opts$plotband$s, 4)
  expect_error(st$actions$set_options(list(ncoef = "abc")), "number")
  # navigation
  st$actions$set_tool("plotband")
  st$actions$nxt()
  st$actions$nxt()
  expect_equal(st$result$time, 5:8)
  st$actions$prev()
  expect_equal(st$subsample, 1)
  st$actions$set_nav("100")
  expect_equal(st$subsample, ceiling(62 / 4))
  st$actions$set_series(1, all = TRUE)
  expect_equal(st$last_call$args$series, "all")
  st$actions$set_tool("vboxplot")
  st$actions$set_nav("3")
  expect_equal(st$result$call$highlight, 3)
  # pair selection and text options
  st$actions$set_tool("vident2")
  st$actions$set_series(1, 3)
  expect_s3_class(st$result, "tsx_vident2")
  st$actions$set_tool("vgranger")
  st$actions$set_options(list(lags = "1:2", tests = "a-b"))
  expect_equal(st$result$table$test, "a-b")
  expect_error(st$actions$set_tool("foo"), "Unknown tool")
})

test_that("every tool runs in the tcltk tooltest state", {
  for (y in list(as_tsx_matrix(dla()), as_tsx_matrix(dlp()))) {
    st <- tsexplorer:::tsx_tk_tooltest_state(y, tooltest_defaults(y))
    st$dev <- null_device()
    st$own_dev <- FALSE
    for (tool in names(st$tools)) {
      st$actions$set_tool(tool)
      expect_false(inherits(st$result, "error"), label = paste(tool, "result"))
      expect_s3_class(st$result, paste0("tsx_", tool))
      expect_true(length(tsexplorer:::tsx_gui_text(st$result)) > 0)
    }
    grDevices::dev.off(st$dev)
    if (ncol(y) == 1) expect_false("vident2" %in% names(st$tools))
  }
})

test_that("tcltk toolforecast state gives the same results as the Shiny version", {
  y <- lav()
  f <- ref_input("sim_fc.csv")
  a <- tsexplorer:::tsx_forecast_align(y, f, NULL, 0, NULL)
  st <- tsexplorer:::tsx_tk_toolforecast_state(y, f, NULL, 0, NULL, a)
  st$dev <- null_device()
  st$own_dev <- FALSE
  on.exit(grDevices::dev.off(st$dev))
  st$actions$set_forecast("all")
  st$actions$set_options(list(s = "12", trunc = "2"))
  expect_s3_class(st$result, "tsx_fplot")
  expect_equal(st$last_call$args$forecast, "all")
  expect_equal(st$tables$accuracy, faccuracy(y, f))
  expect_equal(st$tables$compare, fcompare(y, f, trunc = 2))
  st$actions$set_forecast(2)
  st$actions$set_nav("12")
  expect_equal(st$result$time, 133:144)
  txt <- tsexplorer:::tsx_fgui_text(st$tables, st$forecast)
  expect_true(any(grepl("Forecast #2", txt)))
})

test_that("tcltk toolforecast state passes the intervals and the level", {
  y <- lav()
  f <- ref_input("sim_fc.csv")
  st <- rep(0.03, 12)
  a <- tsexplorer:::tsx_forecast_align(y, f, st, 0, NULL)
  s <- tsexplorer:::tsx_tk_toolforecast_state(y, f, st, 0, NULL, a, level = 0.9)
  s$dev <- null_device()
  s$own_dev <- FALSE
  on.exit(grDevices::dev.off(s$dev))
  s$refresh()
  expect_equal(s$tables$accuracy, faccuracy(y, f, st, level = 0.9))
  expect_equal(s$result$upper[133:144, 1], f[, 1] + stats::qnorm(0.95) * 0.03)
  s$actions$set_options(list(level = "0.8"))
  expect_equal(s$tables$accuracy$call$level, 0.8)
  # the plot uses the new level too
  expect_equal(s$result$upper[133:144, 1], f[, 1] + stats::qnorm(0.9) * 0.03)
  expect_error(s$actions$set_options(list(level = "95")), "maximum")
})

test_that("tcltk toolforecast state without overlap shows the plot and the forecasts", {
  y <- lav()
  full <- rbind(matrix(NA, 144, 3), ref_input("sim_fc.csv"))
  a <- tsexplorer:::tsx_forecast_align(y, full, NULL, 144, NULL)
  st <- tsexplorer:::tsx_tk_toolforecast_state(y, full, NULL, 144, NULL, a)
  st$dev <- null_device()
  st$own_dev <- FALSE
  on.exit(grDevices::dev.off(st$dev))
  for (f in list(1, 2, "all")) {
    st$actions$set_forecast(f)
    expect_s3_class(st$result, "tsx_fplot")
    expect_true(st$tables$no_overlap)
    expect_true(any(grepl("forecasts only", tsexplorer:::tsx_fgui_text(st$tables, st$forecast))))
  }
  st$actions$set_nav("13")
  expect_equal(st$result$time, 145:156)
})

test_that("the tcltk windows are built and driven by their menus", {
  testthat::skip_on_cran()
  testthat::skip_if_not(isTRUE(capabilities("tcltk")))
  ok <- tryCatch({
    w <- tcltk::tktoplevel()
    tcltk::tkdestroy(w)
    TRUE
  }, error = function(e) FALSE)
  testthat::skip_if_not(ok, "no display for Tk")
  dev <- null_device()
  on.exit(grDevices::dev.off(dev), add = TRUE)
  y <- as_tsx_matrix(scc)
  st <- tsexplorer:::tooltest_tk(y, tooltest_defaults(y), wait = FALSE, device = dev)
  expect_equal(st$tool, "plotband")
  # the graphics window goes to the right of the text window
  geo <- as.numeric(strsplit(tcltk::tclvalue(tcltk::tkwm.geometry(st$tk$top)), "[x+]")[[1]])
  expect_gt(st$dev_pos$xpos, geo[1] + geo[3])
  expect_true(all(c(st$dev_pos$width, st$dev_pos$height) >= 3))
  txt <- function(s) tcltk::tclvalue(tcltk::tkget(s$tk$text, "1.0", "end"))
  st$actions$set_tool("adftest")
  expect_match(txt(st), "Augmented Dickey-Fuller")
  st$actions$set_tool("vident")
  expect_match(txt(st), "Ljung-Box")
  expect_equal(tcltk::tclvalue(tcltk::tkindex(st$tk$series_menu, "end")), "2")
  # the entries of the Series menu select their own series (invoking the
  # menu, not the action)
  sm <- st$tk$series_menu
  tcltk::tkinvoke(sm, 0)
  expect_equal(st$series(), 1L)
  tcltk::tkinvoke(sm, 1)
  expect_equal(st$series(), 2L)
  st$actions$set_tool("vident2")
  sub <- tcltk::tclvalue(tcltk::tkentrycget(sm, 0, "-menu"))
  tcltk::tcl(sub, "invoke", 1)
  expect_equal(st$series(), c(1L, 2L))
  expect_equal(st$result$series, colnames(y))
  tcltk::tcl(sub, "invoke", 2)
  expect_equal(st$series(), c(1L, 3L))
  sub2 <- tcltk::tclvalue(tcltk::tkentrycget(sm, 1, "-menu"))
  tcltk::tcl(sub2, "invoke", 0)
  expect_equal(st$series(), 2L)
  st$actions$close()
  expect_null(st$tk)

  f <- ref_input("sim_fc.csv")
  a <- tsexplorer:::tsx_forecast_align(lav(), f, NULL, 0, NULL)
  sf <- tsexplorer:::toolforecast_tk(lav(), f, NULL, 0, NULL, a, wait = FALSE, device = dev)
  expect_match(txt(sf), "Forecast #1")
  sf$actions$set_forecast("all")
  expect_match(txt(sf), "Diebold")
  sf$actions$close()
})

test_that("a new call reuses the open tcltk windows", {
  testthat::skip_on_cran()
  testthat::skip_if_not(isTRUE(capabilities("tcltk")))
  ok <- tryCatch({
    w <- tcltk::tktoplevel()
    tcltk::tkdestroy(w)
    TRUE
  }, error = function(e) FALSE)
  testthat::skip_if_not(ok, "no display for Tk")
  dev <- null_device()
  on.exit(grDevices::dev.off(dev), add = TRUE)
  path <- function(s) tcltk::.Tk.ID(s$tk$top)
  txt <- function(s) tcltk::tclvalue(tcltk::tkget(s$tk$text, "1.0", "end"))
  y1 <- as_tsx_matrix(airpas)
  y2 <- as_tsx_matrix(scc)
  s1 <- tsexplorer:::tooltest_tk(y1, tooltest_defaults(y1), wait = FALSE, device = dev)
  p1 <- path(s1)
  s2 <- tsexplorer:::tooltest_tk(y2, tooltest_defaults(y2), wait = FALSE, device = dev)
  # same window, now with the new data; the old state no longer owns it
  expect_equal(path(s2), p1)
  expect_null(s1$tk)
  expect_identical(tsexplorer:::tsx_tk_windows$tooltest, s2)
  s2$actions$set_tool("vident")
  expect_equal(tcltk::tclvalue(tcltk::tkindex(s2$tk$series_menu, "end")), "2")
  s2$actions$close()
  expect_null(tsexplorer:::tsx_tk_main("tooltest"))
  # after closing it, the next call opens a new window
  s3 <- tsexplorer:::tooltest_tk(y1, tooltest_defaults(y1), wait = FALSE, device = dev)
  expect_false(identical(path(s3), p1))
  p3 <- path(s3)

  # toolforecast() has its own windows: it does not reuse those of tooltest()
  f <- ref_input("sim_fc.csv")
  a <- tsexplorer:::tsx_forecast_align(lav(), f, NULL, 0, NULL)
  f1 <- tsexplorer:::toolforecast_tk(lav(), f, NULL, 0, NULL, a, wait = FALSE, device = dev)
  pf <- path(f1)
  expect_false(identical(pf, path(s3)))
  expect_false(is.null(s3$tk))
  expect_identical(tsexplorer:::tsx_tk_windows$tooltest, s3)
  expect_identical(tsexplorer:::tsx_tk_windows$toolforecast, f1)
  f2 <- tsexplorer:::toolforecast_tk(lav(), f, NULL, 0, NULL, a, wait = FALSE, device = dev)
  expect_equal(path(f2), pf)
  expect_null(f1$tk)
  expect_match(txt(f2), "Forecast #1")
  # and tooltest() reuses its own windows, not those of toolforecast()
  s4 <- tsexplorer:::tooltest_tk(y2, tooltest_defaults(y2), wait = FALSE, device = dev)
  expect_equal(path(s4), p3)
  expect_false(is.null(f2$tk))
  f2$actions$close()
  expect_null(tsexplorer:::tsx_tk_main("toolforecast"))
  expect_identical(tsexplorer:::tsx_tk_main("tooltest"), s4)
  s4$actions$close()
  expect_null(tsexplorer:::tsx_tk_main("tooltest"))
})

test_that("tooltest and toolforecast check the requested interface", {
  expect_error(tooltest(airpas, gui = "qt"), "should be one of")
  expect_error(toolforecast(airpas, airpas[1:12], gui = "qt"), "should be one of")
})
