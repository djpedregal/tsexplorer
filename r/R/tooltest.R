# tooltest(): graphical interface of the Tests menu (GUI layer). It contains
# no calculations: it only builds the arguments, calls the exported functions
# of the package and shows their print() and plot() output. Two
# implementations with the same API: Shiny (this file) and tcltk
# (gui-tcltk.R); the shared logic is in gui-common.R.

#' Interactive test tool
#'
#' Graphical interface with a menu with all
#' the exploratory, descriptive and diagnostic tools of the package, a
#' selector of series, the options of each tool and the graphical and text
#' outputs. Every result shown can be obtained without the GUI by calling the
#' corresponding function (e.g. [vident()]) and `print()` / `plot()`.
#'
#' The data may have no dates or have them (`ts`, `zoo`, `xts` or
#' `data.frame` with a date column; see [as_tsx_matrix()]); with dates, the
#' plots with a time axis show them.
#'
#' Two interfaces with the same behaviour are available:
#' * `gui = "tcltk"` (default): a window with the menus *Tests*, *Series*
#'   and *Options*, navigation buttons and the text output, with the plots in
#'   an R graphics window. It only needs the Tcl/Tk support included in R.
#'   Its text and graphics windows are independent of those of
#'   [toolforecast()] and are shared with the results of its tools printed
#'   at the console (see [tsexplorer-package]): a new call reuses them and
#'   brings them to the front.
#' * `gui = "shiny"`: a web application (needs the package `shiny`).
#'
#' @param y Time series data (see [as_tsx_matrix()]).
#' @param names Optional names of the series.
#' @param ... Options per tool, as named lists, e.g.
#'   `vident = list(ncoef = 50, s = 4, npar = 1)` or `varspectrum = list(16)`
#'   (see [tooltest_defaults()]).
#' @param gui `"tcltk"` (default) or `"shiny"`.
#' @param launch.browser Passed to [shiny::runApp()] (only for Shiny).
#' @return For Shiny, called for its side effect (runs the application). For
#'   tcltk, invisibly, an environment with the state of the interface: `tool`,
#'   `opts`, `last_call` and `result` (the object shown).
#' @examples
#' if (interactive()) {
#'   tooltest(airpas)
#'   tooltest(airpas, gui = "shiny")
#'   tooltest(vdif(log(lydia_pinkham)), vident = list(ncoef = 12))
#'   d <- seq(as.Date("1949-01-01"), by = "month", length.out = 144)
#'   tooltest(data.frame(date = d, passengers = as.vector(airpas)))
#' }
#' @export
tooltest <- function(y, names = NULL, ..., gui = c("tcltk", "shiny"),
                     launch.browser = TRUE) {
  gui <- match.arg(gui)
  tsx_check_gui(gui)
  y <- as_tsx_matrix(y, names)
  opts <- tooltest_defaults(y, ...)
  if (gui == "tcltk") return(invisible(tooltest_tk(y, opts)))
  shiny::runApp(shiny::shinyApp(tooltest_ui(y), tooltest_server(y, opts)),
                launch.browser = launch.browser)
}

# Shiny app object (also used by the tests).
tooltest_app <- function(y, names = NULL, ...) {
  tsx_check_gui("shiny")
  y <- as_tsx_matrix(y, names)
  opts <- tooltest_defaults(y, ...)
  shiny::shinyApp(tooltest_ui(y), tooltest_server(y, opts))
}

tooltest_ui <- function(y) {
  tools <- tsx_tools_for(ncol(y))
  groups <- unique(vapply(tools, `[[`, "", "group"))
  choices <- lapply(groups, function(g) {
    ids <- names(tools)[vapply(tools, `[[`, "", "group") == g]
    stats::setNames(ids, vapply(tools[ids], `[[`, "", "label"))
  })
  names(choices) <- groups
  shiny::fluidPage(
    shiny::titlePanel("Test Tool"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectInput("tool", "Tests", choices = choices, selected = "plotband"),
        shiny::uiOutput("series_ui"),
        shiny::uiOutput("nav_ui"),
        shiny::tags$hr(),
        shiny::tags$b("Options"),
        shiny::uiOutput("options_ui"),
        shiny::actionButton("apply", "Apply options")
      ),
      shiny::mainPanel(
        width = 9,
        shiny::plotOutput("plot", height = "560px"),
        shiny::verbatimTextOutput("table")
      )
    )
  )
}

tooltest_server <- function(y, opts) {
  tools <- tsx_tools()
  snames <- colnames(y)
  sidx <- stats::setNames(seq_along(snames), snames)
  function(input, output, session) {
    state <- shiny::reactiveValues(opts = opts, subsample = 0, highlight = 0, error = NULL)
    spec <- shiny::reactive(tools[[input$tool]])

    output$series_ui <- shiny::renderUI({
      sp <- spec()
      switch(sp$series,
             none = NULL,
             single = shiny::selectInput("series", "Series", sidx),
             single_all = shiny::selectInput("series", "Series", c(sidx, All = "all")),
             var = shiny::selectInput("series", "Series", c(sidx, "All (VAR)" = "all")),
             pair = shiny::tagList(
               shiny::selectInput("series", "Series", sidx),
               shiny::selectInput("series2", "Second series (cross functions)", sidx)),
             pair_all = shiny::tagList(
               shiny::checkboxInput("series_all", "All scatter plots", FALSE),
               shiny::selectInput("series", "Series (horizontal axis)", sidx, selected = 1),
               shiny::selectInput("series2", "Series (vertical axis)", sidx, selected = 2)))
    })

    output$nav_ui <- shiny::renderUI({
      sp <- spec()
      if (identical(sp$nav, "subsample")) {
        shiny::tagList(
          shiny::tags$b("Subsample (0 = full sample)"),
          shiny::fluidRow(
            shiny::column(3, shiny::actionButton("prev", "<<<")),
            shiny::column(6, shiny::numericInput("subsample", NULL, state$subsample, min = 0)),
            shiny::column(3, shiny::actionButton("nxt", ">>>"))),
          shiny::checkboxInput("overlay", "All subsamples overlaid", FALSE))
      } else if (identical(sp$nav, "highlight")) {
        shiny::tagList(
          shiny::tags$b("Highlight (0 = none)"),
          shiny::fluidRow(
            shiny::column(3, shiny::actionButton("prev", "<<<")),
            shiny::column(6, shiny::numericInput("highlight", NULL, state$highlight, min = 0)),
            shiny::column(3, shiny::actionButton("nxt", ">>>"))))
      }
    })

    nav_name <- shiny::reactive(if (identical(spec()$nav, "subsample")) "subsample" else "highlight")
    nav_value <- function(nm) if (is.null(input[[nm]]) || is.na(input[[nm]])) 0 else input[[nm]]
    shiny::observeEvent(input$prev, {
      nm <- nav_name()
      shiny::updateNumericInput(session, nm, value = max(0, nav_value(nm) - 1))
    })
    shiny::observeEvent(input$nxt, {
      nm <- nav_name()
      shiny::updateNumericInput(session, nm, value = nav_value(nm) + 1)
    })

    output$options_ui <- shiny::renderUI({
      sp <- spec()
      cur <- state$opts[[input$tool]]
      if (length(sp$options) == 0) return(shiny::helpText("No options."))
      shiny::tagList(lapply(sp$options, function(op) {
        id <- paste0("opt_", op$name)
        val <- cur[[op$name]]
        switch(op$type,
               int = shiny::numericInput(id, op$label, val, min = op$min, step = 1),
               num = shiny::numericInput(id, op$label, val, min = op$min),
               logical = shiny::checkboxInput(id, op$label, isTRUE(as.logical(val))),
               logical2 = shiny::checkboxGroupInput(id, op$label, c("Period" = "1", "Power" = "2"),
                                                    selected = as.character(which(as.logical(val)))),
               select = shiny::selectInput(id, op$label, op$choices, selected = val),
               shiny::textInput(id, op$label, tsx_gui_option_text(op, val)))
      }))
    })

    shiny::observeEvent(input$apply, {
      sp <- spec()
      tool <- input$tool
      new <- state$opts
      ok <- tryCatch({
        for (op in sp$options) {
          v <- input[[paste0("opt_", op$name)]]
          if (op$type == "logical2") v <- c("1", "2") %in% v
          new <- tsx_gui_set_option(new, tool, op$name, tsx_gui_parse_option(op, v))
        }
        TRUE
      }, error = function(e) {
        state$error <- conditionMessage(e)
        FALSE
      })
      if (ok) {
        state$error <- NULL
        state$opts <- new
      }
    })

    series_sel <- shiny::reactive({
      sp <- spec()
      s1 <- input$series
      all <- identical(s1, "all") || (sp$series == "pair_all" && isTRUE(input$series_all))
      s1 <- if (is.null(s1) || identical(s1, "all")) 1L else as.integer(s1)
      s2 <- if (is.null(input$series2)) NULL else as.integer(input$series2)
      tsx_gui_series(sp$series, s1, s2, all)
    })

    # Last call made to the core (tool and arguments), used by the tests.
    last_call <- shiny::reactiveVal(NULL)

    result <- shiny::reactive({
      nav <- list(subsample = nav_value("subsample"), overlay = isTRUE(input$overlay),
                  highlight = nav_value("highlight"))
      run <- tsx_gui_run(y, input$tool, state$opts, series_sel(), nav)
      last_call(run$call)
      run$result
    })

    output$plot <- shiny::renderPlot(tsx_gui_plot(result(), input$tool, series_sel()))

    output$table <- shiny::renderPrint(cat(tsx_gui_text(result(), state$error), sep = "\n"))
  }
}
