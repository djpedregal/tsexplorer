"""Result objects of the tools (lists with class ``tsx_<f>`` in R) and the
dispatch of their text output and plots (print() and plot() methods of R)."""

import sys

import numpy as np

# Text and plot methods of each class (name without "tsx_"), registered by
# the modules of the tools with text_method() and plot_method().
_TEXT = {}
_PLOT = {}

# Options of the package (options(tsexplorer.window) in R): "window" is
# None (automatic: windows in an interactive IPython console), True or
# False.
options = {"window": None}


def text_method(name):
    def register(fun):
        _TEXT[name] = fun
        return fun
    return register


def plot_method(name):
    def register(fun):
        _PLOT[name] = fun
        return fun
    return register


class TsxResult(dict):
    """Result of a tool of the package.

    A ``dict`` whose keys can also be read as attributes (``r.table`` is
    ``r["table"]``). The key ``"class"`` holds ``["tsx_<function>",
    "tsx_result"]``, the class of the object in R. The other keys are the
    fields documented in each function (``call``, ``series``, the tables as
    ``pandas.DataFrame`` and the vectors used by the plots).

    Methods (the ``print()`` and ``plot()`` methods of R):

    * ``text(digits=None)``: lines of the text output (titles, null
      hypotheses, legends and tables), identical to those of R.
    * ``print(digits=None, window=False)``: writes the text; with
      ``window=True``, the text goes to a text window and the plot to a
      graphics window (see ``show()``).
    * ``plot(fig=None, **kwargs)``: draws the plot in a matplotlib figure
      (``fig``, whose contents are replaced, or a new one) and returns it.
    * ``show(digits=None)``: text in the text window and plot in the
      graphics window, those of ``tooltest`` (or of ``toolforecast`` for
      ``faccuracy``, ``fcompare`` and ``fplot``).

    ``repr()`` and ``str()`` give the text output. In an interactive IPython
    console a result displayed at the prompt goes to the windows (as
    ``print()`` in an interactive R session), unless
    ``tsexplorer.options["window"] = False``; in a Jupyter notebook the text
    and the plot are shown in the notebook.
    """

    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError:
            raise AttributeError(name) from None

    def __setattr__(self, name, value):
        self[name] = value

    def __dir__(self):
        return list(super().__dir__()) + [k for k in self if k.isidentifier()]

    @property
    def _name(self):
        return self["class"][0][4:]

    def has_text(self):
        """Has the class a text output of its own?"""
        return self._name in _TEXT

    def has_plot(self):
        """Has the class a plot?"""
        return self._name in _PLOT

    def text(self, digits=None):
        """Lines of the text output (list of str)."""
        fun = _TEXT.get(self._name)
        if fun is None:
            return tsx_text_result(self)
        return fun(self, digits)

    def print(self, digits=None, window=False):
        """Write the text output (``window=False``) or send the text and the
        plot to the windows of the package (``window=True``)."""
        if window:
            self.show(digits)
        else:
            sys.stdout.write("\n".join(self.text(digits)) + "\n")

    def plot(self, fig=None, **kwargs):
        """Draw the plot in the matplotlib figure ``fig`` (its contents are
        replaced) or in a new figure, and return the figure."""
        fun = _PLOT.get(self._name)
        if fun is None:
            raise ValueError("No plot available for objects of class %s." % self["class"][0])
        if fig is None:
            import matplotlib.pyplot as plt
            fig = plt.figure()
        else:
            fig.clf()
        fun(self, fig, **kwargs)
        return fig

    def show(self, digits=None):
        """Show the text in the text window and the plot in the graphics
        window of the package."""
        from ._windows import tsx_show
        return tsx_show(self, digits)

    def __repr__(self):
        return "\n".join(self.text())

    __str__ = __repr__

    def _repr_pretty_(self, p, cycle):
        p.text(self.__repr__())

    def _ipython_display_(self):
        from ._windows import tsx_ipython_display
        tsx_ipython_display(self)


def tsx_result(fun, **fields):
    """Constructor of the result objects of the package."""
    r = TsxResult()
    r["class"] = ["tsx_" + fun, "tsx_result"]
    r.update(fields)
    return r


def tsx_text_result(r):
    """Default text output: the class and the fields of the result with
    their types and sizes (print.tsx_result() shows the structure in R)."""
    out = ["<%s>" % r["class"][0]]
    for k, v in r.items():
        if k == "class":
            continue
        if hasattr(v, "shape"):
            size = " [" + "x".join(str(s) for s in v.shape) + "]"
        elif isinstance(v, (list, tuple, dict)):
            size = " [%d]" % len(v)
        else:
            size = ""
        out.append(" $ %s: %s%s" % (k, type(v).__name__, size))
    return out


class TsxNoOverlapError(ValueError):
    """The actual values and the forecasts do not overlap (class
    ``tsx_no_overlap`` of the R version): no accuracy measures can be
    computed."""


def _isnan(v):
    return v is None or (isinstance(v, (float, np.floating)) and np.isnan(v))
