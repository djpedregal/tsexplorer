"""tsexplorer: exploratory, descriptive and diagnostic tools for time series.

Exploratory, descriptive and diagnostic tools for univariate and
multivariate time series, and tools to evaluate and compare forecasts
(Diego J. Pedregal, Universidad de Castilla-La Mancha). Python version of
the R package ``tsexplorer``.

Every tool is a pure function that takes a ``T x m`` data set (time in rows,
series in columns; see :func:`as_tsx_matrix`) and returns a
:class:`TsxResult`, a ``dict`` (also readable as attributes) with the same
fields as the object returned by the R version and the methods ``text()``,
``print()``, ``plot()`` (matplotlib) and ``show()``. The graphical
interfaces :func:`tooltest` and :func:`toolforecast` (tkinter) give
interactive access to all of them. Options are keyword arguments, e.g.
``vident(y, ncoef=24, npar=2)``.

A result displayed at the console shows its text (``repr()``);
``r.show()`` sends its table to a text window and its plot to a graphics
window. :func:`tooltest` and :func:`toolforecast` have independent windows,
one text window and one graphics window each: the results of the tools of
:func:`tooltest` go to its windows and those of :func:`faccuracy`,
:func:`fcompare` and :func:`fplot` to the windows of :func:`toolforecast`
(the windows of the interface if it is open). Each output replaces the
previous one, and a new call of :func:`tooltest` or :func:`toolforecast`
reuses its own windows and brings them to the front. In an IPython console
displaying a result goes to the windows; in a Jupyter notebook the text and
the plot are shown in the notebook; ``tsexplorer.options["window"] = False``
keeps the text at the console.

Plots and descriptive statistics
    plotband (time series plot with confidence bands), vboxplot (box plot
    by groups of s observations), vtboxplot (transpose box plot), vscatter
    (scatter plots), sumstats (summary statistics), vhist (histogram with
    gaussian and non-parametric densities), vqqplot (normal QQ plot),
    gausstest (gaussianity tests).
Identification
    vident (sample ACF and PACF), vident2 (multivariate sample
    autocorrelation functions), varsbc (information criteria of AR and VAR
    models), vgranger (Granger causality tests).
Heteroskedasticity
    vcusum (CUSUM and CUSUMSQ tests), stdmean (standard deviation - mean
    plots), testhet (heteroskedasticity tests), vboxcox (Box-Cox
    transformation).
Unit roots and cointegration
    adftest (augmented Dickey-Fuller tests), vphillips (Phillips-Perron
    tests), johansentest (Johansen cointegration tests).
Non-linearity
    nltests (non-linearity tests based on squares), vtsay (Tsay 1986 test),
    varsbc2 (SBC of squares), vbds (BDS test of independence).
Spectral analysis
    vcumperiod (cumulative periodogram), vspectrum (spectrum, cross
    spectrum, gains and coherence), varspectrum (autoregressive spectrum).
Forecast evaluation
    faccuracy (accuracy measures), fcompare (comparison tests), fplot (plot
    of actual values and forecasts).
Output
    TsxResult (results and their methods text, print, plot and show),
    options, mainloop.
Graphical interfaces
    tooltest (interactive test tool), toolforecast (interactive forecasting
    tool).
Utilities
    as_tsx_matrix (input data), vdif (differencing), meda (median absolute
    deviation), adfcritical (p-values of Dickey-Fuller statistics),
    tooltest_defaults (default options of the tools), load_data (example
    datasets), TsxNoOverlapError.
"""

from ._result import TsxNoOverlapError, TsxResult, options
from ._utils_input import as_tsx_matrix
from ._utils_math import meda, vdif
from ._data import load_data
from ._plotband import plotband, vboxplot, vtboxplot
from ._distribution import vhist, vqqplot, vscatter
from ._sumstats import sumstats
from ._gausstest import gausstest
from ._vcusum import stdmean, vcusum
from ._vident import vident, vident2
from ._varsbc import varsbc, varsbc2
from ._vgranger import vgranger
from ._testhet import testhet
from ._vboxcox import vboxcox
from ._adftest import adfcritical, adftest
from ._vphillips import vphillips
from ._johansentest import johansentest
from ._nltests import nltests, vtsay
from ._vbds import vbds
from ._spectrum import varspectrum, vcumperiod, vspectrum
from ._forecast import faccuracy, fcompare, fplot
from ._defaults import tooltest_defaults
from ._windows import mainloop
from ._gui_tk import toolforecast, tooltest

__version__ = "0.1.0"

__all__ = [
    "TsxNoOverlapError", "TsxResult", "adfcritical", "adftest", "as_tsx_matrix",
    "faccuracy", "fcompare", "fplot", "gausstest", "johansentest", "load_data", "mainloop", "meda",
    "nltests", "options", "plotband", "stdmean", "sumstats", "testhet", "toolforecast", "tooltest", "tooltest_defaults", "varsbc",
    "varsbc2", "varspectrum", "vbds", "vboxcox", "vboxplot", "vcumperiod", "vcusum", "vdif",
    "vgranger", "vhist", "vident", "vident2", "vphillips", "vqqplot", "vscatter", "vspectrum",
    "vtboxplot", "vtsay",
]
