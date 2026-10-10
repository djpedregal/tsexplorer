# tcltk versions of tooltest() and toolforecast() (GUI layer).
#
# Layout: a window with the menus
# (Tests / Series / Options, or Series / Forecasts / Options), the navigation
# controls (<<< value >>>) and the text output, and the plots in an R
# graphics window.
#
# Each interface keeps its state in an environment. The widgets only call the
# functions stored in state$actions (set_tool, set_series, prev, nxt, ...),
# which change the state and call refresh(); the computations are done by the
# shared functions of gui-common.R. The tests drive the interface through
# state$actions.

# ---------------------------------------------------------------------------
# Small tcltk helpers

tsx_tk_text_set <- function(txt, lines) {
  if (is.null(txt)) return(invisible())
  tcltk::tkconfigure(txt, state = "normal")
  tcltk::tkdelete(txt, "1.0", "end")
  tcltk::tkinsert(txt, "end", paste(lines, collapse = "\n"))
  tcltk::tkconfigure(txt, state = "disabled")
  invisible()
}

tsx_tk_enable <- function(w, on) {
  if (is.null(w)) return(invisible())
  tcltk::tcl(w, "state", if (on) "!disabled" else "disabled")
  invisible()
}

# Graphics window of an interface: reuse it while it is open.
tsx_tk_device <- function(state) {
  if (is.null(state$dev) || !(state$dev %in% grDevices::dev.list())) {
    tsx_tk_screen_device(state$dev_pos)
    state$dev <- grDevices::dev.cur()
  } else {
    grDevices::dev.set(state$dev)
  }
  invisible(state$dev)
}

# Open an on-screen graphics device in a window of its own, like the text
# window: the device of the platform, not the default one (dev.new() opens
# the Plots pane in RStudio, and a pdf file when R is not interactive, e.g.
# under Rscript). 'pos' (see tsx_tk_place()) gives the position (pixels) and
# size (inches) of the window; quartz() has no position. Without an
# on-screen device (e.g. RStudio Server) the default device is used.
tsx_tk_screen_device <- function(pos = NULL) {
  pos <- as.list(pos)
  ok <- tryCatch({
    if (.Platform$OS.type == "windows") {
      do.call(getExportedValue("grDevices", "windows"), pos)
    } else if (capabilities("aqua")) {
      do.call(getExportedValue("grDevices", "quartz"), pos[intersect(names(pos), c("width", "height"))])
    } else if (capabilities("X11")) {
      do.call(getExportedValue("grDevices", "x11"), pos)
    } else {
      stop("no on-screen device")
    }
    TRUE
  }, error = function(e) FALSE)
  if (!ok) grDevices::dev.new()
  invisible()
}

# Place the text window in the top left corner of the screen and store in
# state$dev_pos the position (pixels) and size (inches) of the graphics
# window, to its right, so that both windows are side by side without
# overlapping. On a narrow screen the text window takes at most half of it.
# 'offset' (pixels) moves both windows down and right (the windows of
# toolforecast() are shifted so that they do not cover exactly those of
# tooltest()).
tsx_tk_place <- function(state, top, offset = 0) {
  tcltk::tcl("update", "idletasks")
  px <- function(...) as.numeric(tcltk::tclvalue(tcltk::tkwinfo(...)))
  sw <- px("screenwidth", top)
  sh <- px("screenheight", top)
  dpi <- px("fpixels", top, "1i")
  margin <- 10
  border <- 20   # window borders (pixels)
  title <- 40    # title bar and task bar (pixels)
  w <- min(px("reqwidth", top), floor(sw / 2) - margin - border)
  h <- min(px("reqheight", top), sh - 2 * margin - 2 * title)
  h <- max(100, h - offset)
  tcltk::tkwm.geometry(top, sprintf("%dx%d+%d+%d", w, h, margin + offset, margin + offset))
  xpos <- margin + offset + w + border + margin
  width <- min(9, max(3, (sw - xpos - margin - border) / dpi))
  height <- min(7, max(3, (sh - 2 * margin - 2 * title - offset) / dpi))
  state$dev_pos <- list(xpos = xpos, ypos = margin + offset, width = width, height = height)
  invisible(state$dev_pos)
}

tsx_tk_close <- function(state) {
  if (!is.null(state$dev) && state$dev %in% grDevices::dev.list() && isTRUE(state$own_dev)) {
    grDevices::dev.off(state$dev)
  }
  if (!is.null(state$tk$top)) tcltk::tkdestroy(state$tk$top)
  state$tk <- NULL
  for (k in ls(tsx_tk_windows)) {
    if (identical(tsx_tk_windows[[k]], state)) rm(list = k, envir = tsx_tk_windows)
  }
  invisible()
}

# Open windows of the package. tooltest() and toolforecast() have their own,
# independent windows: at most one text window and one graphics window for
# each of them. tsx_tk_windows$tooltest and tsx_tk_windows$toolforecast are
# the states of the owners of those text windows: the interface or the plain
# output window of the results printed at the console
# (tsx_tk_output_window()). The graphics window is the device of that state
# (state$dev). A new call of tooltest() (or toolforecast()) reuses its own
# windows while they are open, instead of opening new windows each time.
tsx_tk_windows <- new.env(parent = emptyenv())

# Offset of the windows of each kind (see tsx_tk_place()).
tsx_tk_offset <- function(kind) if (kind == "toolforecast") 40 else 0

# State of the open text window of kind 'kind' ("tooltest" or
# "toolforecast"), or NULL.
tsx_tk_main <- function(kind) {
  st <- tsx_tk_windows[[kind]]
  if (is.null(st) || is.null(st$tk$top)) return(NULL)
  if (tcltk::tclvalue(tcltk::tkwinfo("exists", st$tk$top)) != "1") return(NULL)
  st
}

# Text window of kind 'kind' for a new 'state'. If the text window of that
# kind is open its contents (menus and widgets) are removed and it is
# reused, together with its graphics window; otherwise a new one is created.
# Returns the window and whether it was reused.
tsx_tk_window <- function(kind, title, state, device = NULL) {
  old <- tsx_tk_main(kind)
  reuse <- !is.null(old)
  if (!is.null(device)) {
    if (reuse && isTRUE(old$own_dev) && !is.null(old$dev) && old$dev %in% grDevices::dev.list()) {
      grDevices::dev.off(old$dev)
    }
    state$dev <- device
    state$own_dev <- FALSE
  } else if (reuse) {
    state$dev <- old$dev
    state$own_dev <- old$own_dev
  }
  if (reuse) {
    top <- old$tk$top
    state$dev_pos <- old$dev_pos
    old$tk <- NULL
    old$dev <- NULL
    tcltk::tkconfigure(top, menu = "")
    for (w in as.character(tcltk::tkwinfo("children", top))) tcltk::tcl("destroy", w)
    tcltk::tcl("wm", "deiconify", top)
    tcltk::tkraise(top)
  } else {
    top <- tcltk::tktoplevel()
  }
  tcltk::tkwm.title(top, title)
  tsx_tk_windows[[kind]] <- state
  list(top = top, reused = reuse)
}

# Text window of kind 'kind' for the results printed at the console: the
# open text window of that kind (that of tooltest() or toolforecast() if it
# is open) or, if there is none, a new plain window with a heading and the
# text output.
tsx_tk_output_window <- function(kind = "tooltest", device = NULL) {
  st <- tsx_tk_main(kind)
  if (!is.null(st)) return(st)
  state <- new.env(parent = emptyenv())
  state$dev <- NULL
  state$own_dev <- TRUE
  state$tk <- NULL
  state$actions <- list(close = function() tsx_tk_close(state))
  win <- tsx_tk_window(kind, paste(if (kind == "toolforecast") "Forecasting Tool" else "Test Tool",
                                   "(output)"), state, device)
  top <- win$top
  mb <- tcltk::tkmenu(top)
  tcltk::tkconfigure(top, menu = mb)
  file_menu <- tcltk::tkmenu(mb, tearoff = FALSE)
  tcltk::tkadd(file_menu, "command", label = "Close", command = function() state$actions$close())
  tcltk::tkadd(mb, "cascade", label = "File", menu = file_menu)
  title <- tcltk::ttklabel(top, text = "", font = "TkHeadingFont")
  txt <- tsx_tk_text_widget(top)
  tcltk::tkgrid(title, sticky = "w", padx = 6, pady = 4)
  tcltk::tkgrid(txt$frame, sticky = "nsew", padx = 6, pady = 6)
  tcltk::tkgrid.rowconfigure(top, 1, weight = 1)
  tcltk::tkgrid.columnconfigure(top, 0, weight = 1)
  tcltk::tkwm.protocol(top, "WM_DELETE_WINDOW", function() state$actions$close())
  state$tk <- list(top = top, menubar = mb, title = title, text = txt$text)
  if (!win$reused) tsx_tk_place(state, top, tsx_tk_offset(kind))
  state
}

# Kind of the windows of a result: the forecast evaluation results go to the
# windows of toolforecast(), the rest to those of tooltest().
tsx_tk_kind <- function(x) {
  if (inherits(x, c("tsx_faccuracy", "tsx_fcompare", "tsx_fplot"))) "toolforecast" else "tooltest"
}

# Bring the graphics window and the text window of an interface to the
# front, so that they are not hidden by other windows (e.g. RStudio). The
# graphics window can only be raised on Windows (bringToTop(), windows()
# devices); the text window is deiconified, raised, made topmost for a
# moment (Windows does not let a window raise itself above the active
# application otherwise) and given the focus.
tsx_tk_front <- function(state) {
  dev <- state$dev
  if (.Platform$OS.type == "windows" && !is.null(dev) && dev %in% grDevices::dev.list() &&
      identical(names(grDevices::dev.list())[match(dev, grDevices::dev.list())], "windows")) {
    to_top <- getExportedValue("grDevices", "bringToTop")
    try({
      to_top(dev, stay = TRUE)
      to_top(dev, stay = FALSE)
    }, silent = TRUE)
  }
  top <- state$tk$top
  if (!is.null(top)) {
    try({
      tcltk::tcl("wm", "deiconify", top)
      tcltk::tkraise(top)
      tcltk::tcl("wm", "attributes", top, "-topmost", 1)
      tcltk::tcl("update", "idletasks")
      tcltk::tcl("wm", "attributes", top, "-topmost", 0)
      tcltk::tcl("focus", "-force", top)
    }, silent = TRUE)
  }
  invisible()
}

# Show a result printed at the console: its text (if not NULL) in the text
# window, with 'heading', and its plot (if 'draw') in the graphics window.
tsx_tk_show <- function(x, text, heading, draw) {
  st <- tsx_tk_output_window(tsx_tk_kind(x))
  if (!is.null(text)) {
    tcltk::tkconfigure(st$tk$title, text = heading)
    tsx_tk_text_set(st$tk$text, text)
  }
  tcltk::tkraise(st$tk$top)
  if (draw) {
    tsx_tk_device(st)
    graphics::plot(x)
  }
  invisible(st)
}

# Text output window shared by both interfaces (text widget with scroll bars)
tsx_tk_text_widget <- function(parent) {
  frm <- tcltk::ttkframe(parent)
  txt <- tcltk::tktext(frm, width = 100, height = 30, wrap = "none",
                       font = "TkFixedFont", state = "disabled")
  ys <- tcltk::ttkscrollbar(frm, orient = "vertical",
                            command = function(...) tcltk::tkyview(txt, ...))
  xs <- tcltk::ttkscrollbar(frm, orient = "horizontal",
                            command = function(...) tcltk::tkxview(txt, ...))
  tcltk::tkconfigure(txt, yscrollcommand = function(...) tcltk::tkset(ys, ...),
                     xscrollcommand = function(...) tcltk::tkset(xs, ...))
  tcltk::tkgrid(txt, ys, sticky = "nsew")
  tcltk::tkgrid(xs, sticky = "ew")
  tcltk::tkgrid.rowconfigure(frm, 0, weight = 1)
  tcltk::tkgrid.columnconfigure(frm, 0, weight = 1)
  list(frame = frm, text = txt)
}

# Navigation controls: <<< [value] >>> (and an optional check box)
tsx_tk_nav_widget <- function(parent, state, label, check_label = NULL) {
  frm <- tcltk::ttkframe(parent)
  lab <- tcltk::ttklabel(frm, text = label)
  prev <- tcltk::ttkbutton(frm, text = "<<<", width = 5, command = function() state$actions$prev())
  var <- tcltk::tclVar("0")
  ent <- tcltk::ttkentry(frm, textvariable = var, width = 8, justify = "center")
  nxt <- tcltk::ttkbutton(frm, text = ">>>", width = 5, command = function() state$actions$nxt())
  tcltk::tkbind(ent, "<Return>", function() state$actions$set_nav(tcltk::tclvalue(var)))
  w <- list(frame = frm, label = lab, prev = prev, entry = ent, nxt = nxt, var = var)
  if (!is.null(check_label)) {
    cvar <- tcltk::tclVar("0")
    chk <- tcltk::ttkcheckbutton(frm, text = check_label, variable = cvar,
                                 command = function() state$actions$set_check(tcltk::tclvalue(cvar) == "1"))
    w$check <- chk
    w$check_var <- cvar
    tcltk::tkgrid(lab, prev, ent, nxt, chk, padx = 3, pady = 3)
  } else {
    tcltk::tkgrid(lab, prev, ent, nxt, padx = 3, pady = 3)
  }
  w
}

# Options dialog: one row per option; on OK the values are parsed with
# tsx_gui_parse_option() and passed to 'apply' (a function of a named list).
tsx_tk_options_dialog <- function(parent, title, options, current, apply) {
  if (length(options) == 0) {
    tcltk::tkmessageBox(parent = parent, title = title, message = "No options for this tool.",
                        icon = "info")
    return(invisible())
  }
  dlg <- tcltk::tktoplevel(parent)
  tcltk::tkwm.title(dlg, title)
  frm <- tcltk::ttkframe(dlg, padding = 10)
  tcltk::tkpack(frm, fill = "both", expand = TRUE)
  getters <- list()
  for (op in options) {
    val <- current[[op$name]]
    lab <- tcltk::ttklabel(frm, text = op$label)
    if (op$type == "logical") {
      v <- tcltk::tclVar(if (isTRUE(as.logical(val))) "1" else "0")
      w <- tcltk::ttkcheckbutton(frm, variable = v)
      getters[[op$name]] <- local({ v <- v; function() tcltk::tclvalue(v) == "1" })
    } else if (op$type == "logical2") {
      val <- as.logical(rep_len(val, 2))
      v1 <- tcltk::tclVar(if (val[1]) "1" else "0")
      v2 <- tcltk::tclVar(if (val[2]) "1" else "0")
      w <- tcltk::ttkframe(frm)
      tcltk::tkpack(tcltk::ttkcheckbutton(w, text = "Period", variable = v1), side = "left")
      tcltk::tkpack(tcltk::ttkcheckbutton(w, text = "Power", variable = v2), side = "left")
      getters[[op$name]] <- local({
        v1 <- v1
        v2 <- v2
        function() c(tcltk::tclvalue(v1) == "1", tcltk::tclvalue(v2) == "1")
      })
    } else if (op$type == "select") {
      labs <- names(op$choices)
      sel <- labs[match(as.character(val), as.character(op$choices))]
      v <- tcltk::tclVar(if (is.na(sel)) labs[1] else sel)
      w <- tcltk::ttkcombobox(frm, values = labs, textvariable = v, state = "readonly",
                              width = 30)
      getters[[op$name]] <- local({
        v <- v
        ch <- op$choices
        function() unname(ch[match(tcltk::tclvalue(v), names(ch))])
      })
    } else {
      v <- tcltk::tclVar(tsx_gui_option_text(op, val))
      w <- tcltk::ttkentry(frm, textvariable = v, width = 32)
      getters[[op$name]] <- local({ v <- v; function() tcltk::tclvalue(v) })
    }
    tcltk::tkgrid(lab, w, sticky = "w", padx = 4, pady = 3)
  }
  ok <- function() {
    values <- lapply(getters, function(g) g())
    msg <- tryCatch({
      apply(values)
      NULL
    }, error = function(e) conditionMessage(e))
    if (is.null(msg)) {
      tcltk::tkdestroy(dlg)
    } else {
      tcltk::tkmessageBox(parent = dlg, title = title, message = msg, icon = "error")
    }
  }
  btns <- tcltk::ttkframe(frm)
  tcltk::tkpack(tcltk::ttkbutton(btns, text = "OK", command = ok), side = "left", padx = 4)
  tcltk::tkpack(tcltk::ttkbutton(btns, text = "Cancel", command = function() tcltk::tkdestroy(dlg)),
                side = "left", padx = 4)
  tcltk::tkgrid(btns, columnspan = 2, pady = 8)
  tcltk::tkbind(dlg, "<Return>", ok)
  invisible(dlg)
}

# ---------------------------------------------------------------------------
# tooltest(gui = "tcltk")

# State and actions of the interface (no widgets involved).
tsx_tk_tooltest_state <- function(y, opts) {
  state <- new.env(parent = emptyenv())
  state$y <- y
  state$opts <- opts
  state$tools <- tsx_tools_for(ncol(y))
  state$tool <- "plotband"
  state$s1 <- 1L
  state$s2 <- 1L
  state$all <- FALSE
  state$subsample <- 0
  state$overlay <- FALSE
  state$highlight <- 0
  state$error <- NULL
  state$last_call <- NULL
  state$result <- NULL
  state$dev <- NULL
  state$own_dev <- TRUE
  state$tk <- NULL
  spec <- function() tsx_tools()[[state$tool]]
  state$series <- function() tsx_gui_series(spec()$series, state$s1, state$s2, state$all)
  state$refresh <- function() {
    nav <- list(subsample = state$subsample, overlay = state$overlay,
                highlight = state$highlight)
    run <- tsx_gui_run(state$y, state$tool, state$opts, state$series(), nav)
    state$last_call <- run$call
    state$result <- run$result
    # the core functions clamp the navigation values: show the effective one
    if (!inherits(run$result, "error")) {
      if (identical(spec()$nav, "subsample")) state$subsample <- run$result$call$subsample
      if (identical(spec()$nav, "highlight")) state$highlight <- run$result$call$highlight
    }
    if (isTRUE(spec()$plot)) {
      tsx_tk_device(state)
      tsx_gui_plot(run$result, state$tool, state$series())
    }
    tsx_tk_tooltest_update(state)
    invisible(state)
  }
  state$actions <- list(
    set_tool = function(tool) {
      if (!tool %in% names(state$tools)) stop("Unknown tool: ", tool, call. = FALSE)
      state$tool <- tool
      mode <- spec()$series
      state$s1 <- 1L
      state$s2 <- if (mode == "pair_all") 2L else 1L
      state$all <- FALSE
      state$subsample <- 0
      state$overlay <- FALSE
      state$highlight <- 0
      state$error <- NULL
      tsx_tk_tooltest_menus(state)
      state$refresh()
    },
    set_series = function(s1, s2 = NULL, all = FALSE) {
      state$s1 <- as.integer(s1)
      if (!is.null(s2)) state$s2 <- as.integer(s2)
      state$all <- isTRUE(all)
      state$refresh()
    },
    prev = function() {
      if (identical(spec()$nav, "subsample")) state$subsample <- max(0, state$subsample - 1)
      if (identical(spec()$nav, "highlight")) state$highlight <- max(0, state$highlight - 1)
      state$refresh()
    },
    nxt = function() {
      if (identical(spec()$nav, "subsample")) state$subsample <- state$subsample + 1
      if (identical(spec()$nav, "highlight")) state$highlight <- state$highlight + 1
      state$refresh()
    },
    set_nav = function(value) {
      v <- suppressWarnings(as.numeric(value))
      if (length(v) != 1 || is.na(v)) v <- 0
      if (identical(spec()$nav, "subsample")) state$subsample <- max(0, round(v))
      if (identical(spec()$nav, "highlight")) state$highlight <- max(0, round(v))
      state$refresh()
    },
    set_check = function(on) {
      state$overlay <- isTRUE(on)
      state$refresh()
    },
    set_options = function(values) {
      new <- state$opts
      for (op in spec()$options) {
        if (is.null(names(values)) || !op$name %in% names(values)) next
        new <- tsx_gui_set_option(new, state$tool, op$name,
                                  tsx_gui_parse_option(op, values[[op$name]]))
      }
      state$opts <- new
      state$refresh()
    },
    options_dialog = function() {
      if (is.null(state$tk)) return(invisible())
      tsx_tk_options_dialog(state$tk$top, paste("Options:", spec()$label), spec()$options,
                            state$opts[[state$tool]], state$actions$set_options)
    },
    close = function() tsx_tk_close(state)
  )
  state
}

# Build the window of tooltest(gui = "tcltk").
tooltest_tk <- function(y, opts, wait = !interactive(), device = NULL) {
  state <- tsx_tk_tooltest_state(y, opts)
  win <- tsx_tk_window("tooltest", "Test Tool", state, device)
  top <- win$top
  mb <- tcltk::tkmenu(top)
  tcltk::tkconfigure(top, menu = mb)
  file_menu <- tcltk::tkmenu(mb, tearoff = FALSE)
  tcltk::tkadd(file_menu, "command", label = "Close", command = function() state$actions$close())
  tests_menu <- tcltk::tkmenu(mb, tearoff = FALSE)
  last_group <- NULL
  for (id in names(state$tools)) {
    t <- state$tools[[id]]
    if (!is.null(last_group) && t$group != last_group) tcltk::tkadd(tests_menu, "separator")
    last_group <- t$group
    tcltk::tkadd(tests_menu, "command", label = t$label,
                 command = local({ id <- id; function() state$actions$set_tool(id) }))
  }
  series_menu <- tcltk::tkmenu(mb, tearoff = FALSE)
  tcltk::tkadd(mb, "cascade", label = "File", menu = file_menu)
  tcltk::tkadd(mb, "cascade", label = "Tests", menu = tests_menu)
  tcltk::tkadd(mb, "cascade", label = "Series", menu = series_menu)
  tcltk::tkadd(mb, "command", label = "Options...", command = function() state$actions$options_dialog())
  title <- tcltk::ttklabel(top, text = "", font = "TkHeadingFont")
  nav <- tsx_tk_nav_widget(top, state, "Subsample:", "All subsamples overlaid")
  txt <- tsx_tk_text_widget(top)
  tcltk::tkgrid(title, sticky = "w", padx = 6, pady = 4)
  tcltk::tkgrid(nav$frame, sticky = "w", padx = 6)
  tcltk::tkgrid(txt$frame, sticky = "nsew", padx = 6, pady = 6)
  tcltk::tkgrid.rowconfigure(top, 2, weight = 1)
  tcltk::tkgrid.columnconfigure(top, 0, weight = 1)
  tcltk::tkwm.protocol(top, "WM_DELETE_WINDOW", function() state$actions$close())
  state$tk <- list(top = top, menubar = mb, series_menu = series_menu, title = title, nav = nav,
                   text = txt$text)
  if (!win$reused) tsx_tk_place(state, top)
  state$actions$set_tool("plotband")
  tsx_tk_front(state)
  if (wait) tcltk::tkwait.window(top)
  invisible(state)
}

# Rebuild the Series menu and the navigation controls for the current tool.
tsx_tk_tooltest_menus <- function(state) {
  w <- state$tk
  if (is.null(w)) return(invisible())
  spec <- tsx_tools()[[state$tool]]
  sn <- colnames(state$y)
  m <- length(sn)
  sm <- w$series_menu
  tcltk::tkdelete(sm, 0, "end")
  act <- state$actions
  add <- function(menu, label, s1, s2 = NULL, all = FALSE) {
    # force the arguments now: they are the loop variables of the calls below,
    # and as lazy promises every entry would select the last series
    force(s1)
    force(s2)
    force(all)
    tcltk::tkadd(menu, "command", label = label,
                 command = function() act$set_series(s1, s2, all))
  }
  switch(spec$series,
         none = tcltk::tkadd(sm, "command", label = "(all the series are analysed)",
                             state = "disabled"),
         single = for (i in seq_len(m)) add(sm, sn[i], i),
         single_all = , var = {
           for (i in seq_len(m)) add(sm, sn[i], i)
           tcltk::tkadd(sm, "separator")
           add(sm, if (spec$series == "var") "All (VAR)" else "All", 1L, NULL, TRUE)
         },
         pair = for (i in seq_len(m)) {
           sub <- tcltk::tkmenu(sm, tearoff = FALSE)
           for (j in i:m) add(sub, paste(sn[i], "-", sn[j]), i, j)
           tcltk::tkadd(sm, "cascade", label = sn[i], menu = sub)
         },
         pair_all = {
           for (i in seq_len(m - 1)) {
             sub <- tcltk::tkmenu(sm, tearoff = FALSE)
             for (j in (i + 1):m) add(sub, sn[j], i, j)
             tcltk::tkadd(sm, "cascade", label = sn[i], menu = sub)
           }
           tcltk::tkadd(sm, "separator")
           add(sm, "All", 1L, 2L, TRUE)
         })
  nav_on <- !is.null(spec$nav)
  for (x in c("prev", "entry", "nxt")) tsx_tk_enable(w$nav[[x]], nav_on)
  tsx_tk_enable(w$nav$check, identical(spec$nav, "subsample"))
  tcltk::tkconfigure(w$nav$label, text = if (identical(spec$nav, "highlight")) "Highlight:"
                                         else "Subsample:")
  tcltk::tclvalue(w$nav$check_var) <- "0"
  invisible()
}

# Update title, navigation value and text output after a refresh.
tsx_tk_tooltest_update <- function(state) {
  w <- state$tk
  if (is.null(w)) return(invisible())
  spec <- tsx_tools()[[state$tool]]
  sel <- state$series()
  lab <- if (is.null(sel)) "all series" else if (identical(sel, "all")) "All"
         else paste(colnames(state$y)[sel], collapse = " - ")
  tcltk::tkconfigure(w$title, text = paste0(spec$label, "   [Series: ", lab, "]"))
  v <- if (identical(spec$nav, "subsample")) state$subsample
       else if (identical(spec$nav, "highlight")) state$highlight else 0
  tcltk::tclvalue(w$nav$var) <- as.character(v)
  tsx_tk_text_set(w$text, tsx_gui_text(state$result, state$error))
  invisible()
}

# ---------------------------------------------------------------------------
# toolforecast(gui = "tcltk")

tsx_tk_toolforecast_state <- function(y, py, stdpy, origin, names, a, level = 0.95) {
  state <- new.env(parent = emptyenv())
  state$a <- a
  state$series_names <- colnames(a$y)
  state$s1 <- 1L
  state$forecast <- 1L
  state$s <- 12
  state$subsample <- 0
  state$trunc <- 1
  state$level <- level
  state$last_call <- NULL
  state$result <- NULL
  state$tables <- NULL
  state$dev <- NULL
  state$own_dev <- TRUE
  state$tk <- NULL
  state$refresh <- function() {
    run <- tsx_fgui_run(y, py, stdpy, origin, names, state$s1, state$forecast, state$s,
                        state$subsample, state$level)
    state$last_call <- run$call
    state$result <- run$result
    if (!inherits(run$result, "error")) state$subsample <- run$result$call$subsample
    tsx_tk_device(state)
    tsx_fgui_plot(run$result)
    state$tables <- tsx_fgui_tables(y, py, stdpy, origin, state$s1, state$trunc, state$level,
                                    names, a$nf)
    w <- state$tk
    if (!is.null(w)) {
      fl <- if (identical(state$forecast, "all")) "All" else paste0("#", state$forecast)
      tcltk::tkconfigure(w$title, text = paste0("Series: ", state$series_names[state$s1],
                                                "   Forecast: ", fl))
      tcltk::tclvalue(w$nav$var) <- as.character(state$subsample)
      tsx_tk_text_set(w$text, tsx_fgui_text(state$tables, state$forecast))
    }
    invisible(state)
  }
  options <- list(
    list(name = "s", label = "Length of horizontal axis for plots [4, Inf)", type = "int", min = 4),
    list(name = "trunc", label = "Truncation lag for Diebold-Mariano test [0, Inf)", type = "int",
         min = 0),
    list(name = "level", label = "Confidence level of the intervals (0, 1)", type = "num",
         min = 0.001, max = 0.999))
  state$actions <- list(
    set_series = function(s1) {
      state$s1 <- as.integer(s1)
      state$refresh()
    },
    set_forecast = function(f) {
      state$forecast <- if (identical(f, "all")) "all" else as.integer(f)
      state$refresh()
    },
    prev = function() {
      state$subsample <- max(0, state$subsample - 1)
      state$refresh()
    },
    nxt = function() {
      state$subsample <- state$subsample + 1
      state$refresh()
    },
    set_nav = function(value) {
      v <- suppressWarnings(as.numeric(value))
      state$subsample <- if (length(v) != 1 || is.na(v)) 0 else max(0, round(v))
      state$refresh()
    },
    set_options = function(values) {
      for (op in options) {
        if (op$name %in% names(values)) state[[op$name]] <- tsx_gui_parse_option(op, values[[op$name]])
      }
      state$refresh()
    },
    options_dialog = function() {
      if (is.null(state$tk)) return(invisible())
      tsx_tk_options_dialog(state$tk$top, "Options", options,
                            list(s = state$s, trunc = state$trunc, level = state$level),
                            state$actions$set_options)
    },
    close = function() tsx_tk_close(state)
  )
  state
}

# Build the window of toolforecast(gui = "tcltk").
toolforecast_tk <- function(y, py, stdpy, origin, names, a, level = 0.95,
                            wait = !interactive(), device = NULL) {
  state <- tsx_tk_toolforecast_state(y, py, stdpy, origin, names, a, level)
  win <- tsx_tk_window("toolforecast", "Forecasting Tool", state, device)
  top <- win$top
  mb <- tcltk::tkmenu(top)
  tcltk::tkconfigure(top, menu = mb)
  file_menu <- tcltk::tkmenu(mb, tearoff = FALSE)
  tcltk::tkadd(file_menu, "command", label = "Close", command = function() state$actions$close())
  tcltk::tkadd(mb, "cascade", label = "File", menu = file_menu)
  sn <- state$series_names
  if (length(sn) > 1) {
    series_menu <- tcltk::tkmenu(mb, tearoff = FALSE)
    for (i in seq_along(sn)) {
      tcltk::tkadd(series_menu, "command", label = sn[i],
                   command = local({ i <- i; function() state$actions$set_series(i) }))
    }
    tcltk::tkadd(mb, "cascade", label = "Series", menu = series_menu)
  }
  fmenu <- tcltk::tkmenu(mb, tearoff = FALSE)
  for (f in seq_len(a$nf)) {
    tcltk::tkadd(fmenu, "command", label = paste0("#", f),
                 command = local({ f <- f; function() state$actions$set_forecast(f) }))
  }
  if (a$nf > 1) {
    tcltk::tkadd(fmenu, "separator")
    tcltk::tkadd(fmenu, "command", label = "All",
                 command = function() state$actions$set_forecast("all"))
  }
  tcltk::tkadd(mb, "cascade", label = "Forecasts", menu = fmenu)
  tcltk::tkadd(mb, "command", label = "Options...", command = function() state$actions$options_dialog())
  title <- tcltk::ttklabel(top, text = "", font = "TkHeadingFont")
  nav <- tsx_tk_nav_widget(top, state, "Subperiod (0 = full sample):")
  txt <- tsx_tk_text_widget(top)
  tcltk::tkgrid(title, sticky = "w", padx = 6, pady = 4)
  tcltk::tkgrid(nav$frame, sticky = "w", padx = 6)
  tcltk::tkgrid(txt$frame, sticky = "nsew", padx = 6, pady = 6)
  tcltk::tkgrid.rowconfigure(top, 2, weight = 1)
  tcltk::tkgrid.columnconfigure(top, 0, weight = 1)
  tcltk::tkwm.protocol(top, "WM_DELETE_WINDOW", function() state$actions$close())
  state$tk <- list(top = top, menubar = mb, title = title, nav = nav, text = txt$text)
  if (!win$reused) tsx_tk_place(state, top, tsx_tk_offset("toolforecast"))
  state$refresh()
  tsx_tk_front(state)
  if (wait) tcltk::tkwait.window(top)
  invisible(state)
}
