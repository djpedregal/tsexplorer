import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_is_all, tsx_series_index
from ._utils_math import (_lstsq, tsx_hist, tsx_ksdensity, tsx_nanprod, tsx_prctile)
from ._utils_plot import col, tsx_abline, tsx_hist_plot
from ._utils_print import tsx_cat_block, tsx_format_table


def vscatter(y, bins=None, series=(1, 2), names=None):
    """Scatter plots.

    Scatter plot of two series with the least squares line or, for
    ``series="all"``, the matrix of scatter plots with histograms in the
    diagonal.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`), at least two series.
    bins : int, optional
        Number of bins of the histograms. Default ``ceil(sqrt(T))``.
    series : list or str
        Two series (numbers from 1 or names; the first one on the horizontal
        axis) or ``"all"``.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vscatter`` with fields ``call``, ``series``,
        ``data`` (matrix of the series) and ``coef``, a DataFrame with the
        least squares lines of every ordered pair: ``x``, ``y``,
        ``intercept``, ``slope``.

    See Also
    --------
    TsxResult.plot, sumstats

    Examples
    --------
    >>> scc = load_data("scc")
    >>> vscatter(scc)
    >>> vscatter(scc, series="all")
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    if m < 2:
        raise ValueError("'vscatter' needs at least two series.")
    if bins is None:
        bins = math.ceil(math.sqrt(n))
    idx = tsx_series_index(series, names, allow_all=True)
    all_ = tsx_is_all(series)
    if not all_ and len(idx) < 2:
        raise ValueError('Give two series or "all".')
    if not all_:
        idx = idx[:2]
    rows = []
    for i in range(m):
        for j in range(m):
            if i == j:
                continue
            b = tsx_line_fit(y[:, i], y[:, j])
            rows.append({"x": names[i], "y": names[j], "intercept": b[0], "slope": b[1]})
    return tsx_result("vscatter", call={"bins": bins, "series": idx, "all": all_},
                      series=[names[i - 1] for i in idx],
                      data=y[:, [i - 1 for i in idx]], coef=pd.DataFrame(rows))


def tsx_line_fit(x, y):
    """Least squares line of y on x (missing values handled with
    nanprod)."""
    xm = np.column_stack([np.ones(len(x)), x])
    if np.isnan(x).any() or np.isnan(y).any():
        return (np.linalg.inv(tsx_nanprod(xm.T, xm)[0]) @ tsx_nanprod(xm.T, y)[0]).ravel()
    return _lstsq(xm, y)


def vhist(y, bins=None, series=1, names=None):
    """Histogram with gaussian and non-parametric density estimates.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    bins : int, optional
        Number of bins. Default ``ceil(sqrt(T))``.
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vhist`` with fields ``call``, ``series``,
        ``hist`` (DataFrame with bin ``mid``, ``lower``, ``upper`` and
        ``count``) and ``density`` (DataFrame with ``x``, ``normal`` and
        ``kernel``, both scaled to counts).

    See Also
    --------
    TsxResult.plot, vqqplot, gausstest

    Examples
    --------
    >>> vhist(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    """
    y, names, _ = as_tsx_matrix(y, names)
    if bins is None:
        bins = math.ceil(math.sqrt(y.shape[0]))
    bins = tsx_check_int(bins, "bins")
    i = tsx_series_index(series, names)[0]
    d = tsx_hist_data(y[:, i - 1], bins)
    return tsx_result("vhist", call={"bins": bins, "series": i}, series=names[i - 1],
                      hist=d["hist"], density=d["density"])


def tsx_hist_data(z, bins):
    """Histogram, normal density and kernel density."""
    z = z[~np.isnan(z)]
    n = len(z)
    h = tsx_hist(z, bins)
    rz = np.max(z) - np.min(z)
    xaxis = np.linspace(np.min(h["breaks"]), np.max(h["breaks"]), 181)
    normal = n * stats.norm.pdf(xaxis, np.mean(z), np.std(z, ddof=1)) * (rz / bins)
    kern = tsx_ksdensity(z, xaxis) * rz * n / bins
    return {"hist": pd.DataFrame({"mid": h["mids"], "lower": h["breaks"][:-1],
                                  "upper": h["breaks"][1:], "count": h["counts"]}),
            "density": pd.DataFrame({"x": xaxis, "normal": normal, "kernel": kern})}


def vqqplot(y, series=1, names=None):
    """Normal QQ plot.

    Empirical quantiles of one series against the quantiles of a normal
    distribution with the same mean and standard deviation, with the line
    through the 25% and 75% quartiles.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vqqplot`` with fields ``call``, ``series``,
        ``table`` (DataFrame with ``theoretical`` and ``empirical``
        quantiles), ``quartiles`` (dict with the x and y coordinates of the
        quartiles) and ``line`` (dict with the end points of the reference
        line).

    See Also
    --------
    TsxResult.plot, vhist, gausstest

    Examples
    --------
    >>> vqqplot(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    """
    y, names, _ = as_tsx_matrix(y, names)
    i = tsx_series_index(series, names)[0]
    zi = y[:, i - 1]
    zi = np.sort(zi[~np.isnan(zi)])
    n = len(zi)
    qt = stats.norm.ppf((np.arange(1, n + 1) - 0.5) / n, np.mean(zi), np.std(zi, ddof=1))
    x1 = tsx_prctile(qt, [25, 75])[:, 0]
    y1 = tsx_prctile(zi, [25, 75])[:, 0]
    beta = (y1[1] - y1[0]) / (x1[1] - x1[0])
    yini = y1[0] - (x1[0] - qt[0]) * beta
    yend = y1[1] + (qt[n - 1] - x1[1]) * beta
    return tsx_result("vqqplot", call={"series": i}, series=names[i - 1],
                      table=pd.DataFrame({"theoretical": qt, "empirical": zi}),
                      quartiles={"x": x1, "y": y1},
                      line={"x": np.array([qt[0], qt[n - 1]]), "y": np.array([yini, yend])})


# --- Text and plots (print() and plot() methods of R)

@plot_method("vscatter")
def tsx_plot_vscatter(x, fig):
    d = x["data"]
    coef = x["coef"]

    def line(ax, xs, ys, xdata):
        b = coef[(coef["x"] == xs) & (coef["y"] == ys)].iloc[0]
        tsx_abline(ax, b["intercept"], b["slope"], xdata, color=col("red"))

    if not x["call"]["all"]:
        ax = fig.add_subplot(1, 1, 1)
        ax.plot(d[:, 0], d[:, 1], "*", color=col("blue"), linestyle="none")
        line(ax, x["series"][0], x["series"][1], d[:, 0])
        ax.set_xlabel(x["series"][0])
        ax.set_ylabel(x["series"][1])
        ax.set_title("Scatter Plot: Series %s vs %s" % (x["series"][0], x["series"][1]))
        return
    m = d.shape[1]
    axes = fig.subplots(m, m, squeeze=False)
    for i in range(m):
        for j in range(m):
            ax = axes[i, j]
            if i == j:
                tsx_hist_plot(ax, tsx_hist_data(d[:, i], x["call"]["bins"]), axes=False)
            else:
                ax.plot(d[:, j], d[:, i], ".", color=col("blue"), linestyle="none")
                line(ax, x["series"][j], x["series"][i], d[:, j])
                ax.set_xticks([])
                ax.set_yticks([])
            if i == m - 1:
                ax.set_xlabel(x["series"][j], fontsize=8)
            if j == 0:
                ax.set_ylabel(x["series"][i], fontsize=8)
    fig.suptitle("Scatter Plots for All Series")


@text_method("vscatter")
def tsx_text_vscatter(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(title="Least squares lines (y = intercept + slope * x)",
                         table=tsx_format_table(x["coef"], digits,
                                                col_names=["x", "y", "Intercept", "Slope"]))


@plot_method("vhist")
def tsx_plot_vhist(x, fig):
    ax = fig.add_subplot(1, 1, 1)
    tsx_hist_plot(ax, {"hist": x["hist"], "density": x["density"]})
    ax.set_title("Series %s: Histogram, Nonparametric estimate(green) & Theoretical normal(red)"
                 % x["series"], fontsize=9)
    ax.set_xlabel("Series " + x["series"])
    ax.set_ylabel("Data points")


@text_method("vhist")
def tsx_text_vhist(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(title="Series %s: Histogram" % x["series"],
                         table=tsx_format_table(x["hist"], [digits, digits, digits, 0]))


@plot_method("vqqplot")
def tsx_plot_vqqplot(x, fig):
    t = x["table"]
    ax = fig.add_subplot(1, 1, 1)
    ax.plot(t["theoretical"], t["empirical"], "*", color=col("black"), linestyle="none")
    ax.plot(x["line"]["x"], x["line"]["y"], ":", color=col("red"))
    ax.plot(x["quartiles"]["x"], x["quartiles"]["y"], "o-", color=col("red"), linewidth=2,
            markerfacecolor="none")
    ax.set_title("Series %s: Empirical Quantiles vs Gaussian Theoretical Quantiles"
                 % x["series"], fontsize=10)
    ax.set_xlabel("Normal Theoretical Quantiles")
    ax.set_ylabel("Empirical Quantiles")


@text_method("vqqplot")
def tsx_text_vqqplot(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(title="Series %s: QQ plot" % x["series"],
                         table=tsx_format_table(x["table"], digits,
                                                col_names=["Theoretical", "Empirical"]))
