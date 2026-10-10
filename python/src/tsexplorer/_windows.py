# Text and graphics windows of the package (tkinter; the tcltk windows of the
# R version, see gui-tcltk.R).
#
# tooltest() and toolforecast() have their own, independent windows: at most
# one text window and one graphics window for each of them. _WINDOWS holds,
# for each kind ("tooltest" and "toolforecast"), the state of the owner of
# those windows: the interface or the plain output window of the results
# shown with TsxResult.show() (tsx_tk_output_window()). The graphics window
# is a window of its own with a matplotlib figure. A new call reuses the
# windows of its kind while they are open.

import sys

from ._result import options

_WINDOWS = {}
_ROOT = None


def tsx_tk_root():
    """Hidden root window of tkinter shared by the windows of the
    package."""
    global _ROOT
    import tkinter as tk
    ok = False
    if _ROOT is not None:
        try:
            ok = bool(_ROOT.winfo_exists())
        except tk.TclError:
            ok = False
    if not ok:
        _ROOT = tk.Tk()
        _ROOT.withdraw()
    return _ROOT


def tsx_tk_offset(kind):
    """Offset (pixels) of the windows of each kind: those of toolforecast
    are shifted so that they do not cover exactly those of tooltest."""
    return 40 if kind == "toolforecast" else 0


def tsx_tk_kind(x):
    """Kind of the windows of a result: the forecast evaluation results go
    to the windows of toolforecast, the rest to those of tooltest."""
    return "toolforecast" if x["class"][0] in ("tsx_faccuracy", "tsx_fcompare",
                                                 "tsx_fplot") else "tooltest"


class TsxWindows:
    """State of the text window and the graphics window of one kind.

    ``top`` is the text window (a ``tkinter.Toplevel``; the interfaces put
    their menus and widgets in it), ``gtop`` the graphics window, with the
    matplotlib ``figure`` and its ``canvas``. ``owner`` is the interface
    that uses the windows (None for the plain output window); it loses them
    (its ``detach()`` is called) when they are closed or reused."""

    def __init__(self, kind, title):
        import tkinter as tk
        self.kind = kind
        self.root = tsx_tk_root()
        self.top = tk.Toplevel(self.root)
        self.top.title(title)
        self.top.protocol("WM_DELETE_WINDOW", self.close)
        self.gtop = None
        self.figure = None
        self.canvas = None
        self.gpos = None
        self.text = None
        self.heading = None
        self.owner = None
        self.actions = {"close": self.close}

    def exists(self):
        try:
            return self.top is not None and bool(self.top.winfo_exists())
        except Exception:
            return False

    def detach_owner(self):
        owner, self.owner = self.owner, None
        if owner is not None:
            owner.detach()

    def clear(self, title=None):
        """Remove the contents (menus and widgets) of the text window, to
        reuse it."""
        self.detach_owner()
        self.top.config(menu="")
        for w in self.top.winfo_children():
            w.destroy()
        self.text = None
        self.heading = None
        if title is not None:
            self.top.title(title)
        self.top.deiconify()
        self.top.lift()

    def place(self):
        """Place the text window in the top left corner of the screen and
        the graphics window to its right, without overlapping."""
        top = self.top
        top.update_idletasks()
        sw, sh = top.winfo_screenwidth(), top.winfo_screenheight()
        offset = tsx_tk_offset(self.kind)
        margin, border, title = 10, 20, 40
        w = min(top.winfo_reqwidth(), sw // 2 - margin - border)
        h = min(top.winfo_reqheight(), sh - 2 * margin - 2 * title)
        h = max(100, h - offset)
        top.geometry("%dx%d+%d+%d" % (w, h, margin + offset, margin + offset))
        xpos = margin + offset + w + border + margin
        dpi = top.winfo_fpixels("1i")
        gw = int(min(9 * dpi, max(3 * dpi, sw - xpos - margin - border)))
        gh = int(min(7 * dpi, max(3 * dpi, sh - 2 * margin - 2 * title - offset)))
        self.gpos = (gw, gh, xpos, margin + offset)

    def graphics(self):
        """Graphics window (created if it is not open) and its figure."""
        import tkinter as tk
        if self.gtop is not None:
            try:
                if self.gtop.winfo_exists():
                    return self.figure
            except tk.TclError:
                pass
        from matplotlib.backends.backend_tkagg import (FigureCanvasTkAgg,
                                                       NavigationToolbar2Tk)
        from matplotlib.figure import Figure
        self.gtop = tk.Toplevel(self.root)
        self.gtop.title(("Forecasting Tool" if self.kind == "toolforecast" else "Test Tool")
                        + " (graphics)")
        if self.gpos is None:
            self.place()
        gw, gh, gx, gy = self.gpos
        self.gtop.geometry("%dx%d+%d+%d" % (gw, gh, gx, gy))
        dpi = self.gtop.winfo_fpixels("1i")
        self.figure = Figure(figsize=(gw / dpi, gh / dpi), dpi=dpi)
        self.canvas = FigureCanvasTkAgg(self.figure, master=self.gtop)
        toolbar = NavigationToolbar2Tk(self.canvas, self.gtop, pack_toolbar=False)
        toolbar.update()
        toolbar.pack(side=tk.BOTTOM, fill=tk.X)
        self.canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=True)
        self.gtop.protocol("WM_DELETE_WINDOW", self.close_graphics)
        return self.figure

    def draw(self, x, **kwargs):
        """Draw the plot of a result in the graphics window."""
        fig = self.graphics()
        x.plot(fig=fig, **kwargs)
        self.canvas.draw_idle()
        return fig

    def close_graphics(self):
        if self.gtop is not None:
            try:
                self.gtop.destroy()
            except Exception:
                pass
        self.gtop = self.figure = self.canvas = None

    def close(self):
        """Close the text and graphics windows."""
        self.detach_owner()
        self.close_graphics()
        if self.top is not None:
            try:
                self.top.destroy()
            except Exception:
                pass
        self.top = None
        for k in list(_WINDOWS):
            if _WINDOWS[k] is self:
                del _WINDOWS[k]

    def front(self):
        """Bring the windows to the front (the text window is made topmost
        for a moment: Windows does not let a window raise itself above the
        active application otherwise)."""
        for w in (self.gtop, self.top):
            if w is None:
                continue
            try:
                w.deiconify()
                w.lift()
                w.attributes("-topmost", True)
                w.update_idletasks()
                w.attributes("-topmost", False)
            except Exception:
                pass
        try:
            self.top.focus_force()
        except Exception:
            pass


def tsx_tk_main(kind):
    """Open windows of kind ``kind`` ("tooltest" or "toolforecast"), or
    None."""
    st = _WINDOWS.get(kind)
    if st is None or not st.exists():
        _WINDOWS.pop(kind, None)
        return None
    return st


def tsx_tk_window(kind, title):
    """Windows of kind ``kind`` for a new owner: the open text window of
    that kind is emptied and reused, together with its graphics window;
    otherwise new windows are created. Returns the state and whether it was
    reused."""
    st = tsx_tk_main(kind)
    if st is not None:
        st.clear(title)
        st.actions = {"close": st.close}
        return st, True
    st = TsxWindows(kind, title)
    _WINDOWS[kind] = st
    return st, False


def tsx_tk_text_widget(parent, width=100, height=30):
    """Text output widget (fixed font, read only, with scroll bars)."""
    import tkinter as tk
    from tkinter import ttk
    frm = ttk.Frame(parent)
    txt = tk.Text(frm, width=width, height=height, wrap="none", font="TkFixedFont",
                  state="disabled")
    ys = ttk.Scrollbar(frm, orient="vertical", command=txt.yview)
    xs = ttk.Scrollbar(frm, orient="horizontal", command=txt.xview)
    txt.configure(yscrollcommand=ys.set, xscrollcommand=xs.set)
    txt.grid(row=0, column=0, sticky="nsew")
    ys.grid(row=0, column=1, sticky="ns")
    xs.grid(row=1, column=0, sticky="ew")
    frm.rowconfigure(0, weight=1)
    frm.columnconfigure(0, weight=1)
    return frm, txt


def tsx_tk_text_set(txt, lines):
    """Replace the contents of a text widget."""
    if txt is None:
        return
    txt.configure(state="normal")
    txt.delete("1.0", "end")
    txt.insert("end", "\n".join(lines))
    txt.configure(state="disabled")


def tsx_tk_output_window(kind="tooltest"):
    """Text window of kind ``kind`` for the results shown with show(): the
    open text window of that kind (that of tooltest() or toolforecast() if
    it is open) or, if there is none, a new plain window with a heading and
    the text output."""
    st = tsx_tk_main(kind)
    if st is not None:
        return st
    from tkinter import ttk
    import tkinter as tk
    st, reused = tsx_tk_window(kind, ("Forecasting Tool" if kind == "toolforecast"
                                      else "Test Tool") + " (output)")
    top = st.top
    mb = tk.Menu(top)
    fm = tk.Menu(mb, tearoff=False)
    fm.add_command(label="Close", command=lambda: st.actions["close"]())
    mb.add_cascade(label="File", menu=fm)
    top.config(menu=mb)
    st.heading = ttk.Label(top, text="", font="TkHeadingFont")
    frm, st.text = tsx_tk_text_widget(top)
    st.heading.grid(row=0, column=0, sticky="w", padx=6, pady=4)
    frm.grid(row=1, column=0, sticky="nsew", padx=6, pady=6)
    top.rowconfigure(1, weight=1)
    top.columnconfigure(0, weight=1)
    if not reused:
        st.place()
    return st


def tsx_heading(x):
    """Heading of the text window: the class and the series of a result."""
    h = x["class"][0][4:]
    series = x.get("series")
    if series is not None and len(series):
        series = [series] if isinstance(series, str) else list(series)
        h += "   [Series: %s]" % " - ".join(series)
    return h


def tsx_show(x, digits=None):
    """Show a result: its text (if the class has a text output) in the text
    window and its plot (if it has one) in the graphics window of its kind.
    If tkinter cannot open windows, the text is written at the console and
    the plot drawn with pyplot. Returns the state of the windows (or
    None)."""
    try:
        st = tsx_tk_output_window(tsx_tk_kind(x))
        if x.has_text() or not x.has_plot():
            if st.heading is not None:
                st.heading.configure(text=tsx_heading(x))
            tsx_tk_text_set(st.text, x.text(digits))
        if x.has_plot():
            st.draw(x)
        st.front()
        st.root.update()
        _enable_ipython_tk()
        return st
    except Exception as e:  # no display (or Tk not available)
        import tkinter as tk
        if not isinstance(e, (tk.TclError, ImportError, RuntimeError)):
            raise
        if x.has_text() or not x.has_plot():
            sys.stdout.write("\n".join(x.text(digits)) + "\n")
        if x.has_plot():
            import matplotlib.pyplot as plt
            x.plot()
            plt.show(block=False)
        return None


def _ipython_shell():
    try:
        from IPython import get_ipython
        return get_ipython()
    except ImportError:
        return None


def _enable_ipython_tk():
    """In an IPython console, process the events of tkinter while waiting
    for input (%gui tk), so that the windows respond."""
    shell = _ipython_shell()
    if shell is None or shell.__class__.__name__ == "ZMQInteractiveShell":
        return
    try:
        if getattr(shell, "active_eventloop", None) is None:
            shell.enable_gui("tk")
    except Exception:
        pass


def tsx_ipython_display(x):
    """Display of a result in IPython: windows in an IPython console (unless
    tsexplorer.options["window"] is False), text and an inline plot in a
    Jupyter notebook."""
    shell = _ipython_shell()
    notebook = shell is not None and shell.__class__.__name__ == "ZMQInteractiveShell"
    window = options["window"]
    if window is None:
        window = not notebook
    if window:
        x.show()
        return
    sys.stdout.write("\n".join(x.text()) + "\n")
    if notebook and x.has_plot():
        import matplotlib.pyplot as plt
        x.plot()
        plt.show()


def mainloop():
    """Process the events of the windows of the package until they are
    closed (for scripts: in an interactive session the windows respond
    without it)."""
    root = tsx_tk_root()
    while _WINDOWS:
        root.update()
        for k in list(_WINDOWS):
            tsx_tk_main(k)
        if not _WINDOWS:
            break
        root.after(50)
