test_that("print() writes to the console when window = FALSE", {
  r <- vident(airpas)
  # non interactive session (tests): the default is the console
  expect_false(tsexplorer:::tsx_window_default())
  expect_output(print(r), "Univariate Sample ACF")
  expect_equal(utils::capture.output(print(r)), utils::capture.output(print(r, window = FALSE)))
  old <- options(tsexplorer.window = TRUE)
  on.exit(options(old))
  expect_true(tsexplorer:::tsx_window_default())
})

test_that("results printed with window = TRUE go to the shared text and graphics windows", {
  testthat::skip_on_cran()
  testthat::skip_if_not(isTRUE(capabilities("tcltk")))
  ok <- tryCatch({
    w <- tcltk::tktoplevel()
    tcltk::tkdestroy(w)
    TRUE
  }, error = function(e) FALSE)
  testthat::skip_if_not(ok, "no display for Tk")
  # number of graphics operations recorded on the device
  grDevices::pdf(NULL)
  dev <- grDevices::dev.cur()
  grDevices::dev.control("enable")
  on.exit(if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev), add = TRUE)
  ops <- function() {
    grDevices::dev.set(dev)
    length(grDevices::recordPlot()[[1]])
  }
  txt <- function(s) tcltk::tclvalue(tcltk::tkget(s$tk$text, "1.0", "end"))
  path <- function(s) tcltk::.Tk.ID(s$tk$top)
  # plain output window of tooltest (with a null graphics device for the test)
  out <- tsexplorer:::tsx_tk_output_window("tooltest", device = dev)
  p0 <- path(out)
  r <- vident(airpas)
  expect_silent(print(r, window = TRUE))
  expect_match(txt(out), "Univariate Sample ACF")
  expect_gt(ops(), 0)
  # a result without plot: text only, in the same window
  print(adftest(airpas), window = TRUE)
  expect_match(txt(out), "Augmented Dickey-Fuller")
  expect_identical(tsexplorer:::tsx_tk_main("tooltest"), out)
  # tooltest() reuses the text and graphics windows
  y <- as_tsx_matrix(scc)
  st <- tsexplorer:::tooltest_tk(y, tooltest_defaults(y), wait = FALSE)
  expect_equal(path(st), p0)
  expect_equal(st$dev, dev)
  # a result printed at the console goes to the text window of the GUI
  print(sumstats(airpas), window = TRUE)
  expect_match(txt(st), "Data points")
  # forecast results go to the windows of toolforecast, not to tooltest
  grDevices::pdf(NULL)
  dev2 <- grDevices::dev.cur()
  on.exit(if (dev2 %in% grDevices::dev.list()) grDevices::dev.off(dev2), add = TRUE)
  fo <- tsexplorer:::tsx_tk_output_window("toolforecast", device = dev2)
  pfo <- path(fo)
  expect_false(identical(pfo, p0))
  f <- ref_input("sim_fc.csv")
  print(faccuracy(lav(), f), window = TRUE)
  expect_match(txt(fo), "Forecasting Results")
  expect_match(txt(st), "Data points")
  # toolforecast() reuses its own output window, not that of tooltest()
  a <- tsexplorer:::tsx_forecast_align(lav(), f, NULL, 0, NULL)
  sf <- tsexplorer:::toolforecast_tk(lav(), f, NULL, 0, NULL, a, wait = FALSE)
  expect_equal(path(sf), pfo)
  expect_equal(sf$dev, dev2)
  expect_false(is.null(st$tk))
  expect_match(txt(sf), "Forecast #1")
  # closing the windows (the devices belong to the test)
  sf$own_dev <- FALSE
  sf$actions$close()
  st$own_dev <- FALSE
  st$actions$close()
  expect_null(tsexplorer:::tsx_tk_main("toolforecast"))
  expect_null(tsexplorer:::tsx_tk_main("tooltest"))
})

test_that("the graphics window is a window of its own, not the default device", {
  testthat::skip_on_cran()
  testthat::skip_if_not(.Platform$OS.type == "windows")
  # R CMD check may forbid screen devices (_R_CHECK_SCREEN_DEVICE_)
  testthat::skip_if(Sys.getenv("_R_CHECK_SCREEN_DEVICE_") %in% c("stop", "warn"),
                    "screen devices are not allowed")
  # a default device that is not a window (like the Plots pane of RStudio)
  old <- options(device = function(...) grDevices::pdf(NULL))
  on.exit(options(old), add = TRUE)
  tsexplorer:::tsx_tk_screen_device(list(xpos = 0, ypos = 0, width = 3, height = 3))
  dev <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(dev), add = TRUE)
  expect_equal(names(dev), "windows")
})
