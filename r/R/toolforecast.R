# toolforecast(): graphical interface for forecast evaluation (GUI layer).
# It only calls fplot(), faccuracy() and fcompare() and shows their plot()
# and print() output. Two implementations with the same API: Shiny (this
# file) and tcltk (gui-tcltk.R); the shared logic is in gui-common.R.

#' Interactive forecasting tool
#'
#' Graphical interface for the evaluation of forecasts: plot of
#' actual values and forecasts with confidence bands (computed from the
#' standard deviations of the forecasts) and forecast errors,
#' navigation by subperiods, and tables of accuracy measures ([faccuracy()])
#' and comparison tests ([fcompare()]). When the forecasts do not overlap the
#' actual values (e.g. true out-of-sample forecasts) the table shows only the
#' forecasts (and the bounds of their intervals), without actual values nor
#' accuracy measures.
#'
#' The actual values and the forecasts must be of the same type, without
#' dates or with dates (`ts`, `zoo`, `xts` or `data.frame` with a date
#' column; see [faccuracy()]); otherwise an error is raised. With dates, the
#' plots show them on the time axis and the tables include them.
#'
#' Two interfaces with the same behaviour are available: `gui = "tcltk"`
#' (default; a window with the menus *Series*, *Forecasts* and *Options*, the
#' navigation buttons and the tables, with the plot in an R graphics window)
#' and `gui = "shiny"` (a web application, needs the package `shiny`). With
#' tcltk its text and graphics windows are independent of those of
#' [tooltest()] and are shared with the results of [faccuracy()],
#' [fcompare()] and [fplot()] printed at the console (see
#' [tsexplorer-package]): a new call reuses them and brings them to the
#' front.
#'
#' @inheritParams fplot
#' @param level Confidence level of the prediction intervals computed from
#'   `stdpy` (default 0.95), used in the plot and in the interval measures of
#'   [faccuracy()]. It can also be changed in the *Options* of the interface.
#' @param gui `"tcltk"` (default) or `"shiny"`.
#' @param launch.browser Passed to [shiny::runApp()] (only for Shiny).
#' @return For Shiny, called for its side effect (runs the application). For
#'   tcltk, invisibly, an environment with the state of the interface
#'   (`series`, `forecast`, `s`, `subsample`, `trunc`, `level`, `last_call`,
#'   `result` and `tables`).
#' @examples
#' if (interactive()) {
#'   y <- as.vector(log(airpas))
#'   py <- cbind(y[121:132], rep(y[132], 12))
#'   toolforecast(y, py)
#'   toolforecast(y, py, gui = "shiny")
#'   # with 90% intervals of the first forecast (its standard deviations)
#'   toolforecast(y, py, rep(0.05, 12), level = 0.9)
#'   # with dates (actual values and forecasts of the same type)
#'   d <- seq(as.Date("1949-01-01"), by = "month", length.out = 144)
#'   toolforecast(data.frame(date = d, y = y), data.frame(date = d[133:144], py))
#' }
#' @export
toolforecast <- function(y, py, stdpy = NULL, origin = 0, names = NULL, level = 0.95,
                         gui = c("tcltk", "shiny"), launch.browser = TRUE) {
  gui <- match.arg(gui)
  tsx_check_level(level)
  tsx_check_gui(gui)
  a <- tsx_forecast_align(y, py, stdpy, origin, names)
  if (gui == "tcltk") {
    return(invisible(toolforecast_tk(y, py, stdpy, origin, names, a, level)))
  }
  shiny::runApp(shiny::shinyApp(toolforecast_ui(a, level),
                                toolforecast_server(y, py, stdpy, origin, names, a)),
                launch.browser = launch.browser)
}

# Shiny app object (also used by the tests).
toolforecast_app <- function(y, py, stdpy = NULL, origin = 0, names = NULL, level = 0.95) {
  tsx_check_gui("shiny")
  a <- tsx_forecast_align(y, py, stdpy, origin, names)
  shiny::shinyApp(toolforecast_ui(a, level), toolforecast_server(y, py, stdpy, origin, names, a))
}

toolforecast_ui <- function(a, level = 0.95) {
  snames <- colnames(a$y)
  sidx <- stats::setNames(seq_along(snames), snames)
  fch <- stats::setNames(as.character(seq_len(a$nf)), paste0("#", seq_len(a$nf)))
  if (a$nf > 1) fch <- c(fch, All = "all")
  shiny::fluidPage(
    shiny::titlePanel("Forecasting Tool"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        if (length(snames) > 1) shiny::selectInput("series", "Series", sidx),
        shiny::selectInput("forecast", "Forecasts", fch, selected = "1"),
        shiny::tags$b("Subperiod (0 = full sample)"),
        shiny::fluidRow(
          shiny::column(3, shiny::actionButton("prev", "<<<")),
          shiny::column(6, shiny::numericInput("subsample", NULL, 0, min = 0)),
          shiny::column(3, shiny::actionButton("nxt", ">>>"))),
        shiny::tags$hr(),
        shiny::tags$b("Options"),
        shiny::numericInput("s", "Length of horizontal axis for plots [4, Inf)", 12, min = 4),
        shiny::numericInput("trunc", "Truncation lag for Diebold-Mariano test", 1, min = 0),
        shiny::numericInput("level", "Confidence level of the intervals (0, 1)", level,
                            min = 0.001, max = 0.999, step = 0.01)
      ),
      shiny::mainPanel(
        width = 9,
        shiny::tabsetPanel(
          shiny::tabPanel("Plot", shiny::plotOutput("plot", height = "560px")),
          shiny::tabPanel("Table", shiny::verbatimTextOutput("table"))
        )
      )
    )
  )
}

toolforecast_server <- function(y, py, stdpy, origin, names, a) {
  function(input, output, session) {
    num <- function(v, default) if (is.null(v) || is.na(v)) default else v
    series <- shiny::reactive(if (is.null(input$series)) 1L else as.integer(input$series))
    forecast <- shiny::reactive({
      f <- input$forecast
      if (is.null(f)) 1L else if (f == "all") "all" else as.integer(f)
    })
    shiny::observeEvent(input$prev, {
      shiny::updateNumericInput(session, "subsample", value = max(0, num(input$subsample, 0) - 1))
    })
    shiny::observeEvent(input$nxt, {
      shiny::updateNumericInput(session, "subsample", value = num(input$subsample, 0) + 1)
    })
    last_call <- shiny::reactiveVal(NULL)
    plot_obj <- shiny::reactive({
      run <- tsx_fgui_run(y, py, stdpy, origin, names, series(), forecast(), num(input$s, 12),
                          num(input$subsample, 0), num(input$level, 0.95))
      last_call(run$call)
      run$result
    })
    output$plot <- shiny::renderPlot(tsx_fgui_plot(plot_obj()))
    tables <- shiny::reactive({
      tsx_fgui_tables(y, py, stdpy, origin, series(), num(input$trunc, 1),
                      num(input$level, 0.95), names, a$nf)
    })
    output$table <- shiny::renderPrint(cat(tsx_fgui_text(tables(), forecast()), sep = "\n"))
  }
}
