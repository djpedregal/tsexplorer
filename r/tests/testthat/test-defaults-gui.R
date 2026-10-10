test_that("tooltest_defaults gives the documented default options", {
  d <- tooltest_defaults(airpas)
  expect_equal(d$vident$ncoef, 38)
  expect_equal(d$adftest$lags, 1:12)
  expect_equal(d$vphillips$ncovs, floor(4 * (144 / 100)^0.25))
  expect_equal(d$testhet$timecuts, c(48, 98))
  expect_equal(d$vscatter$bins, 12)
  expect_equal(d$nltests$ncoef, 12)
  d2 <- tooltest_defaults(scc)
  expect_equal(d2$adftest$lags, 7)
  expect_equal(d2$vgranger$tests, c("b-a", "c-a", "a-b", "c-b", "a-c", "b-c"))
  expect_equal(d2$vident$ncoef, min(38, ceiling(62 / 4 / 3 * 2)))
})

test_that("tooltest_defaults applies overrides and linked options", {
  d <- tooltest_defaults(airpas, vident = list(ncoef = 50, s = 4, npar = 1),
                         varspectrum = list(20))
  expect_equal(d$vident$ncoef, 50)
  expect_equal(d$varspectrum$order, 20)
  # linked seasonal period and lags
  expect_equal(d$plotband$s, 4)
  expect_equal(d$stdmean$s, 4)
  expect_equal(d$vboxcox$group, 4)
  expect_equal(d$varsbc$ncoef, 50)
  d <- tooltest_defaults(airpas, vphillips = list(lags = 1:3))
  expect_equal(d$adftest$lags, 1:3)
  expect_equal(d$johansentest$lags, 1:3)
  expect_error(tooltest_defaults(airpas, foo = list(1)), "Unknown tool")
  expect_error(tooltest_defaults(airpas, vident = list(zz = 1)), "Unknown option")
})

test_that("tsx_parse_numbers reads numeric vectors without evaluating code", {
  p <- tsexplorer:::tsx_parse_numbers
  expect_equal(p("1:4"), 1:4)
  expect_equal(p("1 2 12"), c(1, 2, 12))
  expect_equal(p("[-1 : 0.5 : 1]"), seq(-1, 1, 0.5))
  expect_equal(p("1 30; 50 90", matrix = TRUE), rbind(c(1, 30), c(50, 90)))
  expect_error(p("system('ls')"))
})

test_that("tooltest server calls the core with the expected options", {
  testthat::skip_if_not_installed("shiny")
  y <- as_tsx_matrix(scc)
  opts <- tooltest_defaults(y)
  shiny::testServer(tsexplorer:::tooltest_server(y, opts), {
    session$setInputs(tool = "vident", series = "2")
    r <- result()
    expect_s3_class(r, "tsx_vident")
    expect_equal(last_call()$args$series, 2L)
    expect_equal(last_call()$args$ncoef, opts$vident$ncoef)
    expect_equal(r, vident(y, ncoef = opts$vident$ncoef, s = 12, npar = 0, series = 2))

    # changing an option with Apply (and propagation of the linked period)
    session$setInputs(opt_ncoef = 10, opt_s = 4, opt_npar = 1, apply = 1)
    expect_equal(result()$call$ncoef, 10)
    expect_equal(state$opts$plotband$s, 4)

    session$setInputs(tool = "adftest")
    expect_s3_class(result(), "tsx_adftest")
    expect_null(last_call()$args$series)

    session$setInputs(tool = "plotband", series = "all", subsample = 2, overlay = FALSE)
    expect_equal(last_call()$args$series, "all")
    expect_equal(result()$time, 5:8)  # s = 4 after the linked change above

    session$setInputs(tool = "vident2", series = "1", series2 = "3")
    expect_s3_class(result(), "tsx_vident2")

    session$setInputs(tool = "vgranger", opt_lags = "1:2", opt_tests = "a-b", apply = 2)
    expect_equal(result()$table$test, "a-b")
  })
})

test_that("every tool of the menu runs and renders in tooltest", {
  testthat::skip_if_not_installed("shiny")
  for (y in list(as_tsx_matrix(dla()), as_tsx_matrix(dlp()))) {
    opts <- tooltest_defaults(y)
    tools <- tsexplorer:::tsx_tools()
    if (ncol(y) == 1) tools <- tools[!vapply(tools, function(t) isTRUE(t$multi), logical(1))]
    shiny::testServer(tsexplorer:::tooltest_server(y, opts), {
      for (tool in names(tools)) {
        session$setInputs(tool = tool, series = "1", series2 = "1", series_all = FALSE)
        if (tool == "vscatter") session$setInputs(series2 = "2")
        r <- result()
        expect_false(inherits(r, "error"), label = paste(tool, "result"))
        expect_s3_class(r, paste0("tsx_", tool))
        expect_true(nchar(paste(output$table, collapse = "")) > 0, label = paste(tool, "table"))
        expect_false(is.null(output$options_ui), label = paste(tool, "options"))
        if (isTRUE(tools[[tool]]$plot)) expect_false(is.null(output$plot), label = paste(tool, "plot"))
      }
    })
  }
})

test_that("toolforecast server calls fplot, faccuracy and fcompare", {
  testthat::skip_if_not_installed("shiny")
  y <- lav()
  f <- ref_input("sim_fc.csv")
  a <- tsexplorer:::tsx_forecast_align(y, f, NULL, 0, NULL)
  shiny::testServer(tsexplorer:::toolforecast_server(y, f, NULL, 0, NULL, a), {
    session$setInputs(forecast = "all", s = 12, subsample = 0, trunc = 2)
    p <- plot_obj()
    expect_s3_class(p, "tsx_fplot")
    expect_equal(last_call()$args$forecast, "all")
    tb <- tables()
    expect_equal(tb$accuracy, faccuracy(y, f))
    expect_equal(tb$compare, fcompare(y, f, trunc = 2))
    session$setInputs(forecast = "2", subsample = 12)
    expect_equal(plot_obj()$time, 133:144)
  })
  # intervals and confidence level
  st <- rep(0.03, 12)
  a <- tsexplorer:::tsx_forecast_align(y, f, st, 0, NULL)
  shiny::testServer(tsexplorer:::toolforecast_server(y, f, st, 0, NULL, a), {
    session$setInputs(forecast = "all", s = 12, subsample = 0, trunc = 1, level = 0.8)
    expect_equal(tables()$accuracy, faccuracy(y, f, st, level = 0.8))
    expect_false(is.na(tables()$accuracy$table$mis[1]))
    expect_equal(plot_obj()$upper[133:144, 1], f[, 1] + stats::qnorm(0.9) * 0.03)
  })
})
