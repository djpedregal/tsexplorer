# Code shared by the graphical interfaces tooltest() and toolforecast()
# (gui-common.R in the R version). Nothing here depends on a GUI toolkit: it
# describes the tools, converts the values typed by the user into options and
# calls the exported functions of the package.

import copy
import math
import re

import numpy as np
import pandas as pd

from ._adftest import adftest
from ._forecast import faccuracy, fcompare, fplot, tsx_period_text
from ._distribution import vhist, vqqplot, vscatter
from ._gausstest import gausstest
from ._johansentest import johansentest
from ._nltests import nltests, vtsay
from ._plotband import plotband, vboxplot, vtboxplot
from ._result import TsxNoOverlapError
from ._spectrum import varspectrum, vcumperiod, vspectrum
from ._sumstats import sumstats
from ._testhet import testhet
from ._utils_input import tsx_format_dates
from ._utils_math import tsx_seq_by
from ._utils_print import tsx_cat_block, tsx_format_g, tsx_format_table, tsx_num2str
from ._varsbc import varsbc, varsbc2
from ._vbds import vbds
from ._vboxcox import vboxcox
from ._vcusum import stdmean, vcusum
from ._vgranger import vgranger
from ._vident import vident, vident2
from ._vphillips import vphillips


def _o(name, label, type, **kw):
    return dict(name=name, label=label, type=type, **kw)


def tsx_tools():
    """Registry of the tools of the Tests menu (menu order and groups).
    series: how the series are selected; multi: needs m > 1."""
    return {
        "plotband": dict(label="Plot", group="Plots and statistics", fun=plotband,
                         series="single_all", plot=True, nav="subsample",
                         options=[_o("s", "Seasonal period for plots [2, Inf)", "int", min=2),
                                  _o("standard", "Standardized plot (all series)", "logical"),
                                  _o("fixed", "Fixed vertical scale", "logical")]),
        "vboxplot": dict(label="Boxplot", group="Plots and statistics", fun=vboxplot,
                         series="single", plot=True, nav="highlight",
                         options=[_o("s", "Seasonal period for box plots [2, Inf)", "int",
                                     min=2)]),
        "vtboxplot": dict(label="Transpose boxplot", group="Plots and statistics", fun=vtboxplot,
                          series="single", plot=True, nav="highlight",
                          options=[_o("s", "Seasonal period [2, Inf)", "int", min=2)]),
        "vscatter": dict(label="Scatter plots", group="Plots and statistics", fun=vscatter,
                         series="pair_all", plot=True, multi=True,
                         options=[_o("bins", "Number of bins for histograms [4, Inf)", "int",
                                     min=4)]),
        "sumstats": dict(label="Summary statistics (table)", group="Plots and statistics",
                         fun=sumstats, series="none", plot=False,
                         options=[_o("digits", "Number of decimals [0, Inf)", "int", min=0),
                                  _o("gaussian", "Gaussian distribution for the mean test",
                                     "logical"),
                                  _o("nsimul", "Simulations for the empirical mean test", "int",
                                     min=10)]),
        "vhist": dict(label="Histogram", group="Distribution", fun=vhist, series="single",
                      plot=True, options=[_o("bins", "Number of bins [4, Inf)", "int", min=4)]),
        "vqqplot": dict(label="QQ plot", group="Distribution", fun=vqqplot, series="single",
                        plot=True, options=[]),
        "gausstest": dict(label="Gaussianity tests (table)", group="Distribution", fun=gausstest,
                          series="none", plot=False,
                          options=[_o("digits", "Number of decimals [0, Inf)", "int", min=0)]),
        "vident": dict(label="Univariate ACF and PACF", group="Identification", fun=vident,
                       series="single", plot=True,
                       options=[_o("ncoef", "Number of lags [4, Inf)", "int", min=4),
                                _o("s", "Seasonal period [2, Inf)", "int", min=2),
                                _o("npar", "Number of model parameters [0, Inf)", "int",
                                   min=0)]),
        "vident2": dict(label="Vector ACF and PACF", group="Identification", fun=vident2,
                        series="pair", plot=True, multi=True, series_in_plot=True,
                        options=[_o("ncoef", "Number of lags [4, Inf)", "int", min=4),
                                 _o("s", "Seasonal period [2, Inf)", "int", min=2),
                                 _o("npar", "Number of model parameters [0, Inf)", "int", min=0),
                                 _o("type", "Partial function", "select",
                                    choices=[("Partial lag autocorrelations", 0),
                                             ("Partial autoregressions", 1)])]),
        "varsbc": dict(label="Information criteria", group="Identification", fun=varsbc,
                       series="var", plot=True,
                       options=[_o("ncoef", "Maximum order [1, Inf)", "int", min=1)]),
        "vgranger": dict(label="Granger causality tests (table)", group="Identification",
                         fun=vgranger, series="none", plot=False, multi=True,
                         options=[_o("lags", "Lags of the VAR (e.g. 1:4 or 1 2 12)", "intvec"),
                                  _o("tests", "Tests (e.g. a-b ab-c)", "text")]),
        "vcusum": dict(label="CUSUM and CUSUMSQ", group="Heteroskedasticity", fun=vcusum,
                       series="single", plot=True, options=[]),
        "stdmean": dict(label="S.D.-Mean and MEDA-Median plots", group="Heteroskedasticity",
                        fun=stdmean, series="single", plot=True,
                        options=[_o("s", "Seasonal period [2, Inf)", "int", min=2),
                                 _o("type", "Type of plot", "select",
                                    choices=[("S.D. vs Mean", 0), ("MEDA vs Median", 1),
                                             ("Range vs Mean", 2)]),
                                 _o("numbers", "Numbers on/off", "logical")]),
        "testhet": dict(label="Heteroskedasticity tests (table)", group="Heteroskedasticity",
                        fun=testhet, series="none", plot=False,
                        options=[_o("timecuts", "Time cuts (e.g. 48 96, or 1 30; 50 90)",
                                    "matrix")]),
        "vboxcox": dict(label="Box-Cox transformation", group="Heteroskedasticity", fun=vboxcox,
                        series="single", plot=True,
                        options=[_o("group", "Observations per group [2, Inf)", "int", min=2),
                                 _o("axislambdas", "Lambdas for plots (e.g. -1:0.1:1)",
                                    "numvec")]),
        "adftest": dict(label="Augmented Dickey-Fuller test (table)", group="Unit roots",
                        fun=adftest, series="none", plot=False,
                        options=[_o("lags", "Lags (e.g. 1:10)", "intvec")]),
        "vphillips": dict(label="Phillips-Perron test (table)", group="Unit roots", fun=vphillips,
                          series="none", plot=False,
                          options=[_o("lags", "Lags (e.g. 1:10)", "intvec"),
                                   _o("ncovs", "Number of covariances [0, Inf)", "int", min=0)]),
        "johansentest": dict(label="Johansen test (table)", group="Unit roots", fun=johansentest,
                             series="none", plot=False,
                             options=[_o("lags", "Lags (e.g. 3 or 2:6)", "intvec")]),
        "nltests": dict(label="MLL, MT and PR non-linearity tests", group="Non-linearity",
                        fun=nltests, series="single", plot=True,
                        options=[_o("ncoef", "Number of lags [4, Inf)", "int", min=4)]),
        "vtsay": dict(label="Tsay (1986) non-linearity test (table)", group="Non-linearity",
                      fun=vtsay, series="none", plot=False,
                      options=[_o("lags", "Lags of the AR model [2, Inf)", "int", min=2)]),
        "varsbc2": dict(label="SBC of squares", group="Non-linearity", fun=varsbc2,
                        series="single", plot=True,
                        options=[_o("ncoef", "Maximum order [1, Inf)", "int", min=1)]),
        "vbds": dict(label="BDS test (table)", group="Non-linearity", fun=vbds, series="none",
                     plot=False,
                     options=[_o("maxdim", "Maximum dimension [2, T/2)", "int", min=2),
                              _o("distance", "Distance as a fraction of the S.D. (0, Inf)", "num",
                                 min=0.01)]),
        "vcumperiod": dict(label="Cumulative periodogram", group="Spectral", fun=vcumperiod,
                           series="single", plot=True, options=[]),
        "vspectrum": dict(label="Spectrum", group="Spectral", fun=vspectrum, series="pair",
                          plot=True,
                          options=[_o("smooth", "Length of triangular window [1, T/4)", "int",
                                      min=1),
                                   _o("xlog", "Log scale (period axis, power axis)",
                                      "logical2")]),
        "varspectrum": dict(label="VAR spectrum", group="Spectral", fun=varspectrum,
                            series="single", plot=True,
                            options=[_o("order", "Order of AR model [1, T/4]", "int", min=1),
                                     _o("nfreq", "Number of frequencies (0 for Fourier)", "int",
                                        min=0),
                                     _o("xlog", "Log scale (period axis, power axis)",
                                        "logical2")]),
    }


def tsx_tools_for(m):
    """Tools of the Tests menu available for m series (tools needing several
    series are removed when m = 1)."""
    tools = tsx_tools()
    if m == 1:
        tools = {k: v for k, v in tools.items() if not v.get("multi", False)}
    return tools


def _seq(a, b, by=None):
    if by is None:
        by = 1.0 if b >= a else -1.0
    if by == 0 or (b - a) * by < 0:
        raise ValueError("Invalid sequence: wrong sign of the increment.")
    return list(tsx_seq_by(a, b, by))


def tsx_parse_numbers(txt, matrix=False):
    """Parse a numeric vector or matrix written in a text box: "1:10",
    "1 2 12", "c(1, 3)", "-1:0.1:1", "1 30; 50 90". No code is evaluated.
    Returns a list of numbers (a list of rows for a matrix with several
    rows) or None if there are no numbers."""
    if txt is None:
        return None
    if isinstance(txt, (list, tuple, np.ndarray)):
        txt = " ".join(str(v) for v in np.ravel(txt))
    txt = re.sub(r"c\(|\)|\[|\]", " ", str(txt))
    txt = re.sub(r"\s*:\s*", ":", txt)
    rows = []
    for r in txt.split(";"):
        out = []
        for tk in [t for t in re.split(r"[\s,]+", r.strip()) if t != ""]:
            try:
                parts = [float(p) for p in tk.split(":")]
            except ValueError:
                raise ValueError("Invalid number: " + tk) from None
            if any(math.isnan(p) for p in parts):
                raise ValueError("Invalid number: " + tk)
            if len(parts) == 1:
                out += parts
            elif len(parts) == 2:
                out += _seq(parts[0], parts[1])
            else:
                out += _seq(parts[0], parts[2], parts[1])
        if out:
            rows.append(out)
    if not rows:
        return None
    if matrix and len(rows) > 1:
        return rows
    return [v for r in rows for v in r]


def _num(x):
    return tsx_num2str(float(x))


def tsx_format_numbers(x):
    """Text of a numeric vector or matrix for a text box (the inverse of
    tsx_parse_numbers())."""
    if x is None:
        return ""
    a = np.asarray(x, dtype=float)
    if a.ndim == 2 and a.shape[0] > 1:
        return "; ".join(" ".join(_num(v) for v in row) for row in a)
    a = a.ravel()
    if len(a) > 2 and np.all(np.diff(a) == 1):
        return "%s:%s" % (_num(a[0]), _num(a[-1]))
    d = np.diff(a)
    if len(a) > 2 and np.all(np.abs(d - d[0]) < 1e-9):
        return "%s:%s:%s" % (_num(a[0]), _num(float("%.6g" % d[0])), _num(a[-1]))
    return " ".join(_num(v) for v in a)


def tsx_gui_args(tool, spec, opts, series, nav):
    """Arguments of the call to the core function of a tool."""
    args = dict(opts[tool])
    if spec.get("series_in_plot", False):
        pass  # vident2: the pair of series is an argument of plot()
    elif spec["series"] != "none":
        args["series"] = series
    if spec.get("nav") == "subsample":
        args["subsample"] = nav["subsample"]
        args["overlay"] = nav["overlay"]
    if spec.get("nav") == "highlight":
        args["highlight"] = nav["highlight"]
    return args


def _as_bool(v):
    if isinstance(v, str):
        return v.strip().lower() in ("true", "t")
    return bool(v)


def tsx_gui_parse_option(op, value):
    """Convert the value typed or selected in the GUI into the value of an
    option. Text boxes are parsed with tsx_parse_numbers() (no code is
    evaluated)."""
    t = op["type"]
    if t in ("int", "num"):
        try:
            v = float(value)
            if math.isnan(v):
                raise ValueError
        except (TypeError, ValueError):
            raise ValueError("%s: a number is expected." % op["label"]) from None
        if t == "int":
            v = int(round(v))
        if op.get("min") is not None and v < op["min"]:
            raise ValueError("%s: the minimum is %s." % (op["label"], _num(op["min"])))
        if op.get("max") is not None and v > op["max"]:
            raise ValueError("%s: the maximum is %s." % (op["label"], _num(op["max"])))
        return v
    if t == "logical":
        return _as_bool(value)
    if t == "logical2":
        v = list(value) if isinstance(value, (list, tuple, np.ndarray)) else [value]
        return [_as_bool(v[k % len(v)]) for k in range(2)]
    if t == "select":
        v = float(value)
        return int(v) if v == int(v) else v
    if t == "text":
        if value is None:
            return None
        v = " ".join(value) if isinstance(value, (list, tuple)) else str(value)
        return None if v.strip() == "" else v
    if t == "intvec":
        v = tsx_parse_numbers(value)
        return [] if v is None else [int(e) for e in v]
    if t == "numvec":
        return tsx_parse_numbers(value)
    if t == "matrix":
        return tsx_parse_numbers(value, matrix=True)
    raise ValueError("Unknown type of option: " + t)


def tsx_gui_option_text(op, value):
    """Text shown in a text box for the current value of an option."""
    t = op["type"]
    if t == "text":
        if value is None:
            return ""
        return " ".join(value) if isinstance(value, (list, tuple)) else str(value)
    if t in ("intvec", "numvec", "matrix"):
        return tsx_format_numbers(value)
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float, np.number)):
        return _num(value)
    return str(value)


def tsx_gui_set_option(opts, tool, name, value):
    """Set an option of a tool and propagate it to the linked options
    (attribute links of tooltest_defaults())."""
    out = copy.deepcopy(opts)
    out[tool][name] = value
    for group in opts.links.values():
        if (tool, name) in group:
            for t, k in group:
                out[t][k] = copy.deepcopy(value)
    return out


def tsx_gui_series(mode, s1=1, s2=None, all=False):
    """Series selection given the selection mode of a tool: s1, s2 are
    numbers (from 1), all=True selects "all" when the mode allows it."""
    s1 = int(s1)
    if mode == "none":
        return None
    if mode == "single":
        return s1
    if mode in ("single_all", "var"):
        return "all" if all else s1
    if mode == "pair":
        s2 = s1 if s2 is None else int(s2)
        return s1 if s1 == s2 else [s1, s2]
    if mode == "pair_all":
        return "all" if all else [s1, 2 if s2 is None else int(s2)]
    raise ValueError("Unknown selection mode: " + mode)


def tsx_gui_run(y, tool, opts, series, nav):
    """Run a tool: returns the call made to the core (tool and arguments)
    and the result (or the exception)."""
    spec = tsx_tools()[tool]
    args = tsx_gui_args(tool, spec, opts, series, nav)
    try:
        res = spec["fun"](y, **args)
    except Exception as e:  # shown in the interface
        res = e
    return {"tool": tool, "args": args}, res


def tsx_gui_plot(fig, result, tool, series):
    """Plot the result of a tool in the figure (or the error message)."""
    spec = tsx_tools()[tool]
    if isinstance(result, Exception) or not spec["plot"]:
        fig.clf()
        if isinstance(result, Exception):
            fig.suptitle(str(result), fontsize=9)
        return
    try:
        if spec.get("series_in_plot", False):
            result.plot(fig=fig, series=series)
        else:
            result.plot(fig=fig)
    except Exception as e:  # e.g. vboxcox without a grid of lambdas
        fig.clf()
        fig.suptitle(str(e), fontsize=9)


def tsx_gui_text(result, error=None):
    """Text output of a tool (what print() shows), as a list of lines."""
    out = []
    if error is not None:
        out += ["Error in options: " + str(error), ""]
    if isinstance(result, Exception):
        return out + ["Error: " + str(result)]
    return out + result.text()


# --- toolforecast

def tsx_fgui_tables(y, py, stdpy, origin, series, trunc, level, names, nf):
    """Tables of toolforecast(): accuracy measures of every forecast and,
    with two or more forecasts, the comparison tests. When the actual values
    and the forecasts do not overlap there are no accuracy tables (accuracy
    None, no_overlap True) and 'forecasts' is the fplot() object of all the
    forecasts, for the table of the forecasts only."""
    try:
        acc = faccuracy(y, py, stdpy, origin=origin, series=series, level=level, names=names)
    except TsxNoOverlapError:
        try:
            fc = fplot(y, py, stdpy, origin=origin, series=series, forecast="all", level=level,
                       names=names)
        except Exception as e:
            fc = e
        return {"accuracy": None, "compare": None, "no_overlap": True, "forecasts": fc}
    except Exception as e:
        acc = e
    cmp = None
    if nf > 1:
        try:
            cmp = fcompare(y, py, origin=origin, trunc=trunc, series=series, names=names)
        except Exception as e:
            cmp = e
    return {"accuracy": acc, "compare": cmp, "no_overlap": False}


def tsx_fgui_text(tables, forecast):
    """Text of the tables of toolforecast(): for one forecast the measures
    accumulated by horizon, for all of them the summary table and the
    tests."""
    if tables["no_overlap"]:
        return tsx_fgui_forecast_text(tables["forecasts"], forecast)
    acc = tables["accuracy"]
    if isinstance(acc, Exception):
        return ["Error: " + str(acc)]
    if forecast == "all":
        out = acc.text()
        cmp = tables["compare"]
        if cmp is not None:
            out = out + [""] + (["Error: " + str(cmp)] if isinstance(cmp, Exception)
                                else cmp.text())
        return out
    h = acc["by_horizon"]
    h = h[h["forecast"] == forecast].drop(columns="forecast")
    h = h[[c for c in h.columns if not h[c].isna().all()]]
    if "date" in h.columns:
        h = h.copy()
        h["date"] = tsx_format_dates(h["date"])
    title = ["Forecasting Results", "Series %s, Forecast #%d" % (acc["series"], forecast),
             tsx_period_text(acc["dates"])]
    return tsx_cat_block(title=title, notes="Measures accumulated up to each period",
                         table=tsx_format_table(h, [0] + [3] * (h.shape[1] - 1),
                                                col_names=["bias+mae" if c == "bias_mae" else c
                                                           for c in h.columns]))


def tsx_fgui_forecast_text(p, forecast):
    """Text of toolforecast() when there are no actual values in the
    forecasting period (out of sample forecasts): the table of the
    forecasts, without actual values nor error measures. 'p' is the fplot()
    object of all the forecasts of the series. For one forecast the table
    has the forecast and, with standard deviations, the bounds of its
    intervals; for all of them, the forecasts side by side."""
    if isinstance(p, Exception) or p is None:
        out = ["No actual values in the forecasting period: no accuracy measures."]
        if isinstance(p, Exception):
            out.append("Error: " + str(p))
        return out
    fc = p["forecasts"]
    tt = np.arange(1, fc.shape[0] + 1)
    tt = tt[(tt > p["origin"]) & np.any(~np.isnan(fc), axis=1)]
    all_ = forecast == "all"
    k = list(range(1, fc.shape[1] + 1)) if all_ else int(forecast)
    tab = pd.DataFrame({"t": tt})
    if p["dates"] is not None:
        tab["date"] = tsx_format_dates(p["dates"][tt - 1])
    if all_:
        for j in k:
            tab["F#%d" % j] = fc[tt - 1, j - 1]
    else:
        tab["fcst"] = fc[tt - 1, k - 1]
        if p["lower"] is not None:
            tab["lower"] = p["lower"][tt - 1, k - 1]
            tab["upper"] = p["upper"][tt - 1, k - 1]
    nnum = tab.shape[1] - (1 if p["dates"] is None else 2)
    notes = ["No actual values in the forecasting period: forecasts only"]
    if not all_ and p["lower"] is not None:
        notes.append("lower, upper: bounds of the %s%% prediction intervals"
                     % tsx_format_g(100 * p["call"]["level"]))
    title = ["Forecasting Results",
             "Series %s%s" % (p["series"], ", all forecasts" if all_ else ", Forecast #%d" % k),
             tsx_period_text(None if p["dates"] is None else p["dates"][tt - 1])]
    return tsx_cat_block(title=title, notes=notes,
                         table=tsx_format_table(tab, [0] * (tab.shape[1] - nnum) + [3] * nnum))


def tsx_fgui_run(y, py, stdpy, origin, names, series, forecast, s, subsample, level=0.95):
    """Plot object of toolforecast(): returns the call made to fplot() and
    its result (or the exception)."""
    args = dict(origin=origin, series=series, forecast=forecast, s=s, subsample=subsample,
                level=level, names=names)
    try:
        res = fplot(y, py, stdpy, **args)
    except Exception as e:
        res = e
    return {"fun": "fplot", "args": args}, res


def tsx_fgui_plot(fig, p):
    """Plot of toolforecast() in the figure (or the error message)."""
    if isinstance(p, Exception):
        fig.clf()
        fig.suptitle(str(p), fontsize=9)
    else:
        p.plot(fig=fig)
