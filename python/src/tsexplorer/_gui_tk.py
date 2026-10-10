# tkinter versions of tooltest() and toolforecast() (GUI layer; gui-tcltk.R in
# the R version).
#
# Layout: a window with the menus (File / Tests / Series / Options...), the
# navigation controls (<<< value >>>) and the text output, and the plots in
# a graphics window to its right (see _windows.py).
#
# The interface keeps its state in an object. The widgets only call the
# functions stored in state.actions (set_tool, set_series, prev, nxt, ...),
# which change the state and call refresh(); the computations are done by the
# shared functions of _gui_common.py. The tests drive the interface through
# state.actions.

import sys

import pandas as pd

from ._defaults import tooltest_defaults
from ._gui_common import (tsx_fgui_plot, tsx_fgui_run, tsx_fgui_tables, tsx_fgui_text,
                          tsx_gui_option_text, tsx_gui_parse_option, tsx_gui_plot,
                          tsx_gui_run, tsx_gui_series, tsx_gui_set_option, tsx_gui_text,
                          tsx_tools, tsx_tools_for)
from ._utils_input import as_tsx_matrix
from ._windows import (_enable_ipython_tk, tsx_tk_text_set, tsx_tk_text_widget,
                       tsx_tk_window)


def _interactive():
    """Interactive session (the console of Python or IPython)."""
    if hasattr(sys, "ps1") or sys.flags.interactive:
        return True
    try:
        from IPython import get_ipython
        return get_ipython() is not None
    except ImportError:
        return False


def tsx_tk_enable(w, on):
    if w is not None:
        w.state(["!disabled"] if on else ["disabled"])


def tsx_tk_nav_widget(parent, state, label, check_label=None):
    """Navigation controls: <<< [value] >>> (and an optional check box)."""
    import tkinter as tk
    from tkinter import ttk
    frm = ttk.Frame(parent)
    lab = ttk.Label(frm, text=label)
    prev = ttk.Button(frm, text="<<<", width=5, command=lambda: state.actions["prev"]())
    var = tk.StringVar(frm, value="0")
    ent = ttk.Entry(frm, textvariable=var, width=8, justify="center")
    nxt = ttk.Button(frm, text=">>>", width=5, command=lambda: state.actions["nxt"]())
    ent.bind("<Return>", lambda e: state.actions["set_nav"](var.get()))
    w = {"frame": frm, "label": lab, "prev": prev, "entry": ent, "nxt": nxt, "var": var,
         "check": None, "check_var": None}
    widgets = [lab, prev, ent, nxt]
    if check_label is not None:
        cvar = tk.BooleanVar(frm, value=False)
        chk = ttk.Checkbutton(frm, text=check_label, variable=cvar,
                              command=lambda: state.actions["set_check"](cvar.get()))
        w["check"] = chk
        w["check_var"] = cvar
        widgets.append(chk)
    for k, wd in enumerate(widgets):
        wd.grid(row=0, column=k, padx=3, pady=3)
    return w


def tsx_tk_options_dialog(parent, title, options, current, apply):
    """Options dialog: one row per option; on OK the values are parsed with
    tsx_gui_parse_option() (by ``apply``, a function of a dict of values)
    and errors are shown in a message box."""
    import tkinter as tk
    from tkinter import messagebox, ttk
    if not options:
        messagebox.showinfo(title, "No options for this tool.", parent=parent)
        return None
    dlg = tk.Toplevel(parent)
    dlg.title(title)
    frm = ttk.Frame(dlg, padding=10)
    frm.pack(fill="both", expand=True)
    getters = {}
    for row, op in enumerate(options):
        val = current.get(op["name"])
        lab = ttk.Label(frm, text=op["label"])
        if op["type"] == "logical":
            v = tk.BooleanVar(dlg, value=bool(val))
            w = ttk.Checkbutton(frm, variable=v)
            getters[op["name"]] = v.get
        elif op["type"] == "logical2":
            val = list(val) if isinstance(val, (list, tuple)) else [val, val]
            v1 = tk.BooleanVar(dlg, value=bool(val[0]))
            v2 = tk.BooleanVar(dlg, value=bool(val[1 % len(val)]))
            w = ttk.Frame(frm)
            ttk.Checkbutton(w, text="Period", variable=v1).pack(side="left")
            ttk.Checkbutton(w, text="Power", variable=v2).pack(side="left")
            getters[op["name"]] = (lambda v1=v1, v2=v2: [v1.get(), v2.get()])
        elif op["type"] == "select":
            labels = [c[0] for c in op["choices"]]
            sel = [c[0] for c in op["choices"] if c[1] == val]
            v = tk.StringVar(dlg, value=sel[0] if sel else labels[0])
            w = ttk.Combobox(frm, values=labels, textvariable=v, state="readonly", width=30)
            getters[op["name"]] = (lambda v=v, ch=op["choices"]:
                                   [c[1] for c in ch if c[0] == v.get()][0])
        else:
            v = tk.StringVar(dlg, value=tsx_gui_option_text(op, val))
            w = ttk.Entry(frm, textvariable=v, width=32)
            getters[op["name"]] = v.get
        lab.grid(row=row, column=0, sticky="w", padx=4, pady=3)
        w.grid(row=row, column=1, sticky="w", padx=4, pady=3)

    def ok(*_):
        values = {k: g() for k, g in getters.items()}
        try:
            apply(values)
        except Exception as e:
            messagebox.showerror(title, str(e), parent=dlg)
            return
        dlg.destroy()

    btns = ttk.Frame(frm)
    ttk.Button(btns, text="OK", command=ok).pack(side="left", padx=4)
    ttk.Button(btns, text="Cancel", command=dlg.destroy).pack(side="left", padx=4)
    btns.grid(row=len(options), column=0, columnspan=2, pady=8)
    dlg.bind("<Return>", ok)
    dlg.transient(parent)
    return dlg


class TooltestState:
    """State and actions of tooltest (no widgets involved).

    Attributes: ``y`` (the data, a ``DataFrame`` with the names of the
    series and, for dated data, a ``DatetimeIndex``), ``opts`` (options of
    every tool, see tooltest_defaults()), ``tools`` (the tools of the menu),
    ``tool``, the selection of series (``s1``, ``s2``, ``all``), the
    navigation (``subsample``, ``overlay``, ``highlight``), ``last_call``
    (tool and arguments of the last call to the core) and ``result`` (the
    object shown, or the exception). ``actions`` holds the actions of the
    interface: set_tool, set_series, prev, nxt, set_nav, set_check,
    set_options, options_dialog and close. ``win`` are the windows (None
    without windows, then the plots go to an off-screen figure,
    ``figure``)."""

    def __init__(self, y, opts=None, names=None):
        ym, names, dates = as_tsx_matrix(y, names)
        self.y = pd.DataFrame(ym, columns=names,
                              index=dates if dates is not None else pd.RangeIndex(len(ym)))
        self.names = names
        self.opts = tooltest_defaults(self.y) if opts is None else opts
        self.tools = tsx_tools_for(len(names))
        self.tool = "plotband"
        self.s1 = 1
        self.s2 = 1
        self.all = False
        self.subsample = 0
        self.overlay = False
        self.highlight = 0
        self.error = None
        self.last_call = None
        self.result = None
        self.win = None
        self.tk = None
        self.figure = None
        self.actions = {
            "set_tool": self.set_tool, "set_series": self.set_series, "prev": self.prev,
            "nxt": self.nxt, "set_nav": self.set_nav, "set_check": self.set_check,
            "set_options": self.set_options, "options_dialog": self.options_dialog,
            "close": self.close}

    def spec(self):
        return tsx_tools()[self.tool]

    def series(self):
        return tsx_gui_series(self.spec()["series"], self.s1, self.s2, self.all)

    def detach(self):
        """The windows have been closed or are used by a new interface."""
        self.win = None
        self.tk = None

    def plot_figure(self):
        if self.win is not None:
            return self.win.graphics()
        if self.figure is None:
            from matplotlib.figure import Figure
            self.figure = Figure()
        return self.figure

    def refresh(self):
        spec = self.spec()
        nav = {"subsample": self.subsample, "overlay": self.overlay,
               "highlight": self.highlight}
        self.last_call, self.result = tsx_gui_run(self.y, self.tool, self.opts, self.series(),
                                                  nav)
        # the core functions clamp the navigation values: show the effective one
        if not isinstance(self.result, Exception):
            if spec.get("nav") == "subsample":
                self.subsample = self.result["call"]["subsample"]
            if spec.get("nav") == "highlight":
                self.highlight = self.result["call"]["highlight"]
        if spec["plot"]:
            fig = self.plot_figure()
            tsx_gui_plot(fig, self.result, self.tool, self.series())
            if self.win is not None and self.win.canvas is not None:
                self.win.canvas.draw_idle()
        tsx_tk_tooltest_update(self)
        return self

    # --- actions

    def set_tool(self, tool):
        if tool not in self.tools:
            raise ValueError("Unknown tool: " + str(tool))
        self.tool = tool
        mode = self.spec()["series"]
        self.s1 = 1
        self.s2 = 2 if mode == "pair_all" else 1
        self.all = False
        self.subsample = 0
        self.overlay = False
        self.highlight = 0
        self.error = None
        tsx_tk_tooltest_menus(self)
        return self.refresh()

    def set_series(self, s1, s2=None, all=False):
        self.s1 = int(s1)
        if s2 is not None:
            self.s2 = int(s2)
        self.all = bool(all)
        return self.refresh()

    def prev(self):
        nav = self.spec().get("nav")
        if nav == "subsample":
            self.subsample = max(0, self.subsample - 1)
        if nav == "highlight":
            self.highlight = max(0, self.highlight - 1)
        return self.refresh()

    def nxt(self):
        nav = self.spec().get("nav")
        if nav == "subsample":
            self.subsample += 1
        if nav == "highlight":
            self.highlight += 1
        return self.refresh()

    def set_nav(self, value):
        try:
            v = float(value)
            if v != v:
                v = 0.0
        except (TypeError, ValueError):
            v = 0.0
        nav = self.spec().get("nav")
        if nav == "subsample":
            self.subsample = max(0, int(round(v)))
        if nav == "highlight":
            self.highlight = max(0, int(round(v)))
        return self.refresh()

    def set_check(self, on):
        self.overlay = bool(on)
        return self.refresh()

    def set_options(self, values):
        new = self.opts
        for op in self.spec()["options"]:
            if op["name"] in values:
                new = tsx_gui_set_option(new, self.tool, op["name"],
                                         tsx_gui_parse_option(op, values[op["name"]]))
        self.opts = type(self.opts)(new)
        return self.refresh()

    def options_dialog(self):
        if self.tk is None:
            return None
        spec = self.spec()
        return tsx_tk_options_dialog(self.tk["top"], "Options: " + spec["label"],
                                     spec["options"], self.opts[self.tool],
                                     self.actions["set_options"])

    def close(self):
        if self.win is not None:
            self.win.close()
        self.detach()


def tsx_tk_tooltest_menus(state):
    """Rebuild the Series menu and the navigation controls for the current
    tool."""
    w = state.tk
    if w is None:
        return
    spec = state.spec()
    sn = state.names
    m = len(sn)
    sm = w["series_menu"]
    sm.delete(0, "end")
    for child in list(sm.winfo_children()):
        child.destroy()
    act = state.actions
    import tkinter as tk

    def add(menu, label, s1, s2=None, all=False):
        menu.add_command(label=label,
                         command=lambda s1=s1, s2=s2, all=all: act["set_series"](s1, s2, all))

    mode = spec["series"]
    if mode == "none":
        sm.add_command(label="(all the series are analysed)", state="disabled")
    elif mode == "single":
        for i in range(m):
            add(sm, sn[i], i + 1)
    elif mode in ("single_all", "var"):
        for i in range(m):
            add(sm, sn[i], i + 1)
        sm.add_separator()
        add(sm, "All (VAR)" if mode == "var" else "All", 1, None, True)
    elif mode == "pair":
        for i in range(m):
            sub = tk.Menu(sm, tearoff=False)
            for j in range(i, m):
                add(sub, "%s - %s" % (sn[i], sn[j]), i + 1, j + 1)
            sm.add_cascade(label=sn[i], menu=sub)
    elif mode == "pair_all":
        for i in range(m - 1):
            sub = tk.Menu(sm, tearoff=False)
            for j in range(i + 1, m):
                add(sub, sn[j], i + 1, j + 1)
            sm.add_cascade(label=sn[i], menu=sub)
        sm.add_separator()
        add(sm, "All", 1, 2, True)
    nav = w["nav"]
    nav_on = spec.get("nav") is not None
    for k in ("prev", "entry", "nxt"):
        tsx_tk_enable(nav[k], nav_on)
    tsx_tk_enable(nav["check"], spec.get("nav") == "subsample")
    nav["label"].configure(text="Highlight:" if spec.get("nav") == "highlight"
                           else "Subsample:")
    nav["check_var"].set(False)


def tsx_tk_tooltest_update(state):
    """Update title, navigation value and text output after a refresh."""
    w = state.tk
    if w is None:
        return
    spec = state.spec()
    sel = state.series()
    if sel is None:
        lab = "all series"
    elif sel == "all":
        lab = "All"
    else:
        sel = [sel] if isinstance(sel, int) else sel
        lab = " - ".join(state.names[i - 1] for i in sel)
    w["title"].configure(text="%s   [Series: %s]" % (spec["label"], lab))
    nav = spec.get("nav")
    v = state.subsample if nav == "subsample" else state.highlight if nav == "highlight" else 0
    w["nav"]["var"].set(str(v))
    tsx_tk_text_set(w["text"], tsx_gui_text(state.result, state.error))


def tooltest_tk(y, opts=None, names=None, wait=False):
    """Build the window of tooltest() and return its state."""
    import tkinter as tk
    state = TooltestState(y, opts, names)
    win, reused = tsx_tk_window("tooltest", "Test Tool")
    win.owner = state
    state.win = win
    top = win.top
    mb = tk.Menu(top)
    file_menu = tk.Menu(mb, tearoff=False)
    file_menu.add_command(label="Close", command=lambda: state.actions["close"]())
    tests_menu = tk.Menu(mb, tearoff=False)
    last_group = None
    for tid, t in state.tools.items():
        if last_group is not None and t["group"] != last_group:
            tests_menu.add_separator()
        last_group = t["group"]
        tests_menu.add_command(label=t["label"],
                               command=lambda tid=tid: state.actions["set_tool"](tid))
    series_menu = tk.Menu(mb, tearoff=False)
    mb.add_cascade(label="File", menu=file_menu)
    mb.add_cascade(label="Tests", menu=tests_menu)
    mb.add_cascade(label="Series", menu=series_menu)
    mb.add_command(label="Options...", command=lambda: state.actions["options_dialog"]())
    top.config(menu=mb)
    from tkinter import ttk
    title = ttk.Label(top, text="", font="TkHeadingFont")
    nav = tsx_tk_nav_widget(top, state, "Subsample:", "All subsamples overlaid")
    frm, txt = tsx_tk_text_widget(top)
    title.grid(row=0, column=0, sticky="w", padx=6, pady=4)
    nav["frame"].grid(row=1, column=0, sticky="w", padx=6)
    frm.grid(row=2, column=0, sticky="nsew", padx=6, pady=6)
    top.rowconfigure(2, weight=1)
    top.columnconfigure(0, weight=1)
    state.tk = {"top": top, "menubar": mb, "tests_menu": tests_menu,
                "series_menu": series_menu, "title": title, "nav": nav, "text": txt}
    # the results shown with show() go to this text window
    win.heading = title
    win.text = txt
    if not reused:
        win.place()
    state.actions["set_tool"]("plotband")
    win.front()
    win.root.update()
    _enable_ipython_tk()
    if wait:
        win.root.wait_window(top)
    return state


def tooltest(y, names=None, wait=None, **options):
    """Interactive test tool.

    Graphical interface (tkinter) with a menu with all the exploratory,
    descriptive and diagnostic tools of the package, a selector of series,
    the options of each tool and the graphical and text outputs. Every
    result shown can be obtained without the interface by calling the
    corresponding function (e.g. :func:`vident`) and its methods ``text()``
    and ``plot()``.

    The window has the menus *Tests* (the tools, in groups), *Series* and
    *Options...*, the navigation ``<<< value >>>`` (subsamples of
    ``plotband``, highlighted group of the box plots) and the text output,
    with the plots in a graphics window to its right. Its text and graphics
    windows are independent of those of :func:`toolforecast` and are shared
    with the results of its tools shown with ``show()``: a new call reuses
    them and brings them to the front; closing the text window closes both.

    The data may have no dates or have them (see :func:`as_tsx_matrix`);
    with dates, the plots with a time axis show them.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    names : str or list of str, optional
        Names of the series.
    wait : bool, optional
        Wait until the window is closed. Default: ``True`` in scripts and
        ``False`` in interactive sessions (where the windows respond while
        the console waits for input).
    **options
        Options per tool, e.g. ``vident={"ncoef": 50, "s": 4, "npar": 1}``
        or ``varspectrum=[16]`` (see :func:`tooltest_defaults`).

    Returns
    -------
    TooltestState
        The state of the interface: ``tool``, ``opts``, ``last_call`` and
        ``result`` (the object shown), and its ``actions`` (``set_tool``,
        ``set_series``, ``prev``, ``nxt``, ``set_nav``, ``set_check``,
        ``set_options``, ``options_dialog``, ``close``).

    See Also
    --------
    tooltest_defaults, toolforecast, TsxResult.text, TsxResult.plot

    Examples
    --------
    >>> tooltest(load_data("airpas"))
    >>> tooltest(vdif(np.log(load_data("lydia_pinkham"))), vident={"ncoef": 12})
    >>> d = pd.date_range("1949-01-01", periods=144, freq="MS")
    >>> tooltest(pd.DataFrame({"date": d, "passengers": load_data("airpas").to_numpy()}))
    """
    ym, nm, dates = as_tsx_matrix(y, names)
    data = pd.DataFrame(ym, columns=nm,
                        index=dates if dates is not None else pd.RangeIndex(len(ym)))
    opts = tooltest_defaults(data, **options)
    if wait is None:
        wait = not _interactive()
    return tooltest_tk(data, opts, wait=wait)


# ---------------------------------------------------------------------------
# toolforecast()

TOOLFORECAST_OPTIONS = [
    dict(name="s", label="Length of horizontal axis for plots [4, Inf)", type="int", min=4),
    dict(name="trunc", label="Truncation lag for Diebold-Mariano test [0, Inf)", type="int",
         min=0),
    dict(name="level", label="Confidence level of the intervals (0, 1)", type="num",
         min=0.001, max=0.999)]


class ToolforecastState:
    """State and actions of toolforecast (no widgets involved).

    Attributes: the inputs (``y``, ``py``, ``stdpy``, ``origin``,
    ``names``), ``a`` (their alignment), ``series_names``, ``s1`` (series
    shown, from 1), ``forecast`` (number from 1 or ``"all"``), ``s``
    (length of the subperiods), ``subsample``, ``trunc`` (truncation lag of
    the Diebold-Mariano test), ``level``, ``last_call`` (the call to
    fplot()), ``result`` (the fplot() object, or the exception) and
    ``tables`` (faccuracy() and fcompare() results). ``actions``:
    set_series, set_forecast, prev, nxt, set_nav, set_options,
    options_dialog and close."""

    def __init__(self, y, py, stdpy=None, origin=0, names=None, a=None, level=0.95):
        from ._forecast import tsx_forecast_align
        self.y, self.py, self.stdpy, self.origin, self.names = y, py, stdpy, origin, names
        self.a = tsx_forecast_align(y, py, stdpy, origin, names) if a is None else a
        self.series_names = list(self.a["names"])
        self.s1 = 1
        self.forecast = 1
        self.s = 12
        self.subsample = 0
        self.trunc = 1
        self.level = level
        self.last_call = None
        self.result = None
        self.tables = None
        self.win = None
        self.tk = None
        self.figure = None
        self.actions = {
            "set_series": self.set_series, "set_forecast": self.set_forecast,
            "prev": self.prev, "nxt": self.nxt, "set_nav": self.set_nav,
            "set_options": self.set_options, "options_dialog": self.options_dialog,
            "close": self.close}

    detach = TooltestState.detach
    plot_figure = TooltestState.plot_figure
    close = TooltestState.close

    def refresh(self):
        self.last_call, self.result = tsx_fgui_run(
            self.y, self.py, self.stdpy, self.origin, self.names, self.s1, self.forecast,
            self.s, self.subsample, self.level)
        if not isinstance(self.result, Exception):
            self.subsample = self.result["call"]["subsample"]
        fig = self.plot_figure()
        tsx_fgui_plot(fig, self.result)
        if self.win is not None and self.win.canvas is not None:
            self.win.canvas.draw_idle()
        self.tables = tsx_fgui_tables(self.y, self.py, self.stdpy, self.origin, self.s1,
                                      self.trunc, self.level, self.names, self.a["nf"])
        w = self.tk
        if w is not None:
            fl = "All" if self.forecast == "all" else "#%d" % self.forecast
            w["title"].configure(text="Series: %s   Forecast: %s"
                                 % (self.series_names[self.s1 - 1], fl))
            w["nav"]["var"].set(str(self.subsample))
            tsx_tk_text_set(w["text"], tsx_fgui_text(self.tables, self.forecast))
        return self

    def text(self):
        """Lines of the text output (the tables shown)."""
        return tsx_fgui_text(self.tables, self.forecast)

    # --- actions

    def set_series(self, s1):
        self.s1 = int(s1)
        return self.refresh()

    def set_forecast(self, f):
        self.forecast = "all" if f == "all" else int(f)
        return self.refresh()

    def prev(self):
        self.subsample = max(0, self.subsample - 1)
        return self.refresh()

    def nxt(self):
        self.subsample += 1
        return self.refresh()

    def set_nav(self, value):
        try:
            v = float(value)
            v = 0 if v != v else max(0, int(round(v)))
        except (TypeError, ValueError):
            v = 0
        self.subsample = v
        return self.refresh()

    def set_options(self, values):
        new = {}
        for op in TOOLFORECAST_OPTIONS:
            if op["name"] in values:
                new[op["name"]] = tsx_gui_parse_option(op, values[op["name"]])
        for k, v in new.items():
            setattr(self, k, v)
        return self.refresh()

    def options_dialog(self):
        if self.tk is None:
            return None
        return tsx_tk_options_dialog(self.tk["top"], "Options", TOOLFORECAST_OPTIONS,
                                     {"s": self.s, "trunc": self.trunc, "level": self.level},
                                     self.actions["set_options"])


def toolforecast_tk(y, py, stdpy=None, origin=0, names=None, a=None, level=0.95, wait=False):
    """Build the window of toolforecast() and return its state."""
    import tkinter as tk
    from tkinter import ttk
    state = ToolforecastState(y, py, stdpy, origin, names, a, level)
    win, reused = tsx_tk_window("toolforecast", "Forecasting Tool")
    win.owner = state
    state.win = win
    top = win.top
    mb = tk.Menu(top)
    file_menu = tk.Menu(mb, tearoff=False)
    file_menu.add_command(label="Close", command=lambda: state.actions["close"]())
    mb.add_cascade(label="File", menu=file_menu)
    sn = state.series_names
    series_menu = None
    if len(sn) > 1:
        series_menu = tk.Menu(mb, tearoff=False)
        for i, name in enumerate(sn):
            series_menu.add_command(label=name,
                                    command=lambda i=i: state.actions["set_series"](i + 1))
        mb.add_cascade(label="Series", menu=series_menu)
    fmenu = tk.Menu(mb, tearoff=False)
    nf = state.a["nf"]
    for f in range(1, nf + 1):
        fmenu.add_command(label="#%d" % f, command=lambda f=f: state.actions["set_forecast"](f))
    if nf > 1:
        fmenu.add_separator()
        fmenu.add_command(label="All", command=lambda: state.actions["set_forecast"]("all"))
    mb.add_cascade(label="Forecasts", menu=fmenu)
    mb.add_command(label="Options...", command=lambda: state.actions["options_dialog"]())
    top.config(menu=mb)
    title = ttk.Label(top, text="", font="TkHeadingFont")
    nav = tsx_tk_nav_widget(top, state, "Subperiod (0 = full sample):")
    frm, txt = tsx_tk_text_widget(top)
    title.grid(row=0, column=0, sticky="w", padx=6, pady=4)
    nav["frame"].grid(row=1, column=0, sticky="w", padx=6)
    frm.grid(row=2, column=0, sticky="nsew", padx=6, pady=6)
    top.rowconfigure(2, weight=1)
    top.columnconfigure(0, weight=1)
    state.tk = {"top": top, "menubar": mb, "series_menu": series_menu, "forecasts_menu": fmenu,
                "title": title, "nav": nav, "text": txt}
    win.heading = title
    win.text = txt
    if not reused:
        win.place()
    state.refresh()
    win.front()
    win.root.update()
    _enable_ipython_tk()
    if wait:
        win.root.wait_window(top)
    return state


def toolforecast(y, py, stdpy=None, origin=0, names=None, level=0.95, wait=None):
    """Interactive forecasting tool.

    Graphical interface (tkinter) for the evaluation of forecasts: plot of
    actual values and forecasts with confidence bands (computed from the
    standard deviations of the forecasts) and forecast errors, navigation
    by subperiods, and tables of accuracy measures (:func:`faccuracy`) and
    comparison tests (:func:`fcompare`). When the forecasts do not overlap
    the actual values (e.g. true out-of-sample forecasts) the table shows
    only the forecasts (and the bounds of their intervals), without actual
    values nor accuracy measures.

    The window has the menus *Series* (with several series), *Forecasts*
    (``#1``, ..., ``#n``, *All*) and *Options...* (length of the subperiods,
    truncation lag of the Diebold-Mariano test, confidence level of the
    intervals), the navigation ``<<< subperiod >>>`` (0 = full sample) and
    the tables: for one forecast the measures accumulated by horizon, for
    *All* the summary table and the comparison tests. The plot of
    :func:`fplot` goes to a graphics window to its right. Its windows are
    independent of those of :func:`tooltest` and are shared with the results
    of :func:`faccuracy`, :func:`fcompare` and :func:`fplot` shown with
    ``show()``: a new call reuses them and brings them to the front.

    The actual values and the forecasts must be of the same type, without
    dates or with dates (see :func:`faccuracy`); otherwise an error is
    raised. With dates, the plots show them on the time axis and the tables
    include them.

    Parameters
    ----------
    y, py, stdpy, origin, names
        See :func:`faccuracy`.
    level : float
        Confidence level of the prediction intervals computed from
        ``stdpy`` (default 0.95), used in the plot and in the interval
        measures of :func:`faccuracy`. It can also be changed in the
        *Options* of the interface.
    wait : bool, optional
        Wait until the window is closed. Default: ``True`` in scripts and
        ``False`` in interactive sessions.

    Returns
    -------
    ToolforecastState
        The state of the interface (``s1``, ``forecast``, ``s``,
        ``subsample``, ``trunc``, ``level``, ``last_call``, ``result`` and
        ``tables``) and its ``actions`` (``set_series``, ``set_forecast``,
        ``prev``, ``nxt``, ``set_nav``, ``set_options``, ``options_dialog``,
        ``close``).

    See Also
    --------
    faccuracy, fcompare, fplot, tooltest

    Examples
    --------
    >>> y = np.log(load_data("airpas").to_numpy())
    >>> py = np.column_stack([y[120:132], np.repeat(y[131], 12)])
    >>> toolforecast(y, py)
    >>> # with 90% intervals of the first forecast (its standard deviations)
    >>> toolforecast(y, py, np.repeat(0.05, 12), level=0.9)
    >>> # with dates (actual values and forecasts of the same type)
    >>> d = pd.date_range("1949-01-01", periods=144, freq="MS")
    >>> toolforecast(pd.DataFrame({"date": d, "y": y}),
    ...              pd.DataFrame({"date": d[132:], "f1": py[:, 0], "f2": py[:, 1]}))
    """
    from ._forecast import tsx_check_level, tsx_forecast_align
    tsx_check_level(level)
    a = tsx_forecast_align(y, py, stdpy, origin, names)
    if wait is None:
        wait = not _interactive()
    return toolforecast_tk(y, py, stdpy, origin, names, a, level, wait=wait)
