import math

import numpy as np
import pandas as pd

from ._result import plot_method, text_method, tsx_result
from ._utils_input import (as_tsx_matrix, tsx_check_int, tsx_format_dates, tsx_is_all,
                           tsx_series_index)
from ._utils_plot import col, tsx_dark3, tsx_rainbow, tsx_time_coords, tsx_xlim, tsx_ylim
from ._utils_print import tsx_cat_block, tsx_format_table
from ._utils_math import (nanmax, nanmean, nanmedian, nanmin, nansd, tsx_prctile,
                          tsx_standardize)


def _pad(z, length):
    return np.r_[z, np.full(length - len(z), np.nan)]


def plotband(y, s=12, standard=False, fixed=True, series=1, subsample=0, overlay=False,
             names=None):
    """Time series plot with confidence bands.

    Plot of one series with its mean and mean +/- 2 standard deviations, of
    a subsample of length ``s``, of all the subsamples of length ``s``
    overlaid, or of all the series together (optionally standardised).

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    s : int
        Length of the subsamples (seasonal period). Default 12.
    standard : bool
        For ``series="all"``, plot the standardised series.
    fixed : bool
        Keep the vertical scale of the full sample when plotting a
        subsample.
    series : int, str or list
        One series (number from 1 or name) or ``"all"``.
    subsample : int
        ``0`` for the full sample, ``k`` for the k-th subsample of length
        ``s`` (observations ``(k - 1) * s + 1`` to ``k * s``).
    overlay : bool
        For one series, plot all the subsamples of length ``s`` overlaid
        (one line per subsample).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_plotband`` with fields ``call``, ``series``
        (list of names), ``data`` (the data to plot: a matrix whose rows are
        the time indices ``time``), ``time`` (observation numbers, from 1),
        ``dates`` (dates of ``time`` for dated inputs, ``None`` otherwise or
        with ``overlay``), ``mean``, ``sd``, ``ylim`` and ``n_subsamples``.

    See Also
    --------
    TsxResult.plot, vboxplot, vtboxplot

    Examples
    --------
    >>> airpas = load_data("airpas")
    >>> plotband(airpas)
    >>> plotband(airpas, overlay=True)
    >>> plotband(load_data("scc"), series="all", standard=True)
    """
    y, names, dates = as_tsx_matrix(y, names)
    n = y.shape[0]
    s = min(tsx_check_int(s, "s"), n)
    nsub = math.ceil(n / s)
    subsample = int(min(max(0, round(subsample)), nsub))
    idx = tsx_series_index(series, names, allow_all=True)
    all_series = len(idx) > 1 or tsx_is_all(series)
    if subsample == 0:
        t = np.arange(1, n + 1)
    else:
        t = np.arange((subsample - 1) * s + 1, min(subsample * s, n) + 1)
    if not all_series:
        z = y[:, idx[0] - 1]
        zm = nanmean(z)
        zs = nansd(z)
        if overlay:
            dat = _pad(z, nsub * s).reshape((s, nsub), order="F")
            t = np.arange(1, s + 1)
            ylim = [min(zm - 2 * zs, nanmin(dat)), max(zm + 2 * zs, nanmax(dat))]
        else:
            dat = z[t - 1].reshape(-1, 1)
            ref = z if fixed else z[t - 1]
            ylim = [min(zm - 2 * zs, nanmin(ref)), max(zm + 2 * zs, nanmax(ref))]
    else:
        z = y[:, [i - 1 for i in idx]]
        if standard:
            z = tsx_standardize(z)
        zm = 0.0 if standard else np.nan
        zs = 1.0 if standard else np.nan
        dat = z[t - 1, :]
        ref = z if fixed else dat
        ylim = [nanmin(ref), nanmax(ref)]
    ylim = [float(v) for v in ylim]
    if ylim[0] == ylim[1]:
        ylim = [ylim[0] - 1, ylim[1] + 1]
    pdates = dates[t - 1] if dates is not None and (all_series or not overlay) else None
    return tsx_result(
        "plotband",
        call={"s": s, "standard": standard, "fixed": fixed, "series": idx,
              "subsample": subsample, "overlay": overlay, "all": all_series},
        series=[names[i - 1] for i in idx], data=dat, time=t, dates=pdates, mean=float(zm),
        sd=float(zs), ylim=ylim, n_subsamples=nsub)


def vboxplot(y, s=12, series=1, highlight=0, names=None):
    """Box plot of a time series by groups of ``s`` consecutive observations.

    For each group of ``s`` consecutive observations (e.g. each year of
    monthly data) shows the mean, median, 25% and 75% percentiles, minimum
    and maximum. Optionally highlights the observations of one position
    within the groups (e.g. one month across years).

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    s : int
        Length of the groups (seasonal period). Default 12, limited to
        ``T / 2``.
    series : int or str
        Series to analyse (number from 1 or name).
    highlight : int
        ``0`` for none, or the position ``1..s`` within the groups whose
        values are highlighted.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vboxplot`` with fields ``call``, ``series``,
        ``stats`` (DataFrame with columns ``group``, ``mean``, ``median``,
        ``p25``, ``p75``, ``min``, ``max``), ``highlight`` (values
        highlighted, one per group) and ``group_dates`` (date of the first
        observation of each group for dated inputs, otherwise ``None``).

    See Also
    --------
    TsxResult.plot, vtboxplot, plotband

    Examples
    --------
    >>> vboxplot(load_data("airpas"), highlight=7)
    """
    y, names, dates = as_tsx_matrix(y, names)
    n = y.shape[0]
    s = min(tsx_check_int(s, "s"), n // 2)
    i = tsx_series_index(series, names)[0]
    ng = math.ceil(n / s)
    zi = _pad(y[:, i - 1], ng * s).reshape((s, ng), order="F")
    st = tsx_group_stats(zi)
    st.insert(0, "group", np.arange(1, ng + 1))
    highlight = int(min(max(0, round(highlight)), s))
    hv = y[highlight - 1::s, i - 1] if highlight > 0 else np.zeros(0)
    return tsx_result("vboxplot", call={"s": s, "series": i, "highlight": highlight},
                      series=names[i - 1], stats=st, highlight=hv,
                      group_dates=None if dates is None else dates[::s])


def vtboxplot(y, s=12, series=1, highlight=0, names=None):
    """Transpose box plot of a time series.

    Standardises each group of ``s`` consecutive observations and shows, for
    each position ``1..s`` within the groups (e.g. each month), the mean,
    median, 25% and 75% percentiles, minimum and maximum across groups.
    Optionally highlights one group (e.g. one year).

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    s : int
        Length of the groups (seasonal period). Default 12, limited to
        ``T / 2``.
    series : int or str
        Series to analyse (number from 1 or name).
    highlight : int
        ``0`` for none, or the group ``1..ceil(T / s)`` to highlight.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vtboxplot`` with fields ``call``, ``series``,
        ``stats`` (DataFrame with columns ``position``, ``mean``, ``median``,
        ``p25``, ``p75``, ``min``, ``max``), ``data`` (matrix ``s x groups``
        of standardised values) and ``highlight``.

    See Also
    --------
    TsxResult.plot, vboxplot

    Examples
    --------
    >>> vtboxplot(load_data("airpas"), highlight=12)
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    s = min(tsx_check_int(s, "s"), n // 2)
    i = tsx_series_index(series, names)[0]
    ng = math.ceil(n / s)
    zi = tsx_standardize(_pad(y[:, i - 1], ng * s).reshape((s, ng), order="F"))
    st = tsx_group_stats(zi.T)
    st.insert(0, "position", np.arange(1, s + 1))
    highlight = int(min(max(0, round(highlight)), ng))
    hv = zi[:, highlight - 1] if highlight > 0 else np.zeros(0)
    return tsx_result("vtboxplot", call={"s": s, "series": i, "highlight": highlight},
                      series=names[i - 1], stats=st, data=zi, highlight=hv)


def tsx_group_stats(z):
    """Column statistics of a matrix (columns are the groups)."""
    return pd.DataFrame({
        "mean": nanmean(z, axis=0),
        "median": nanmedian(z, axis=0),
        "p25": tsx_prctile(z, 25)[0],
        "p75": tsx_prctile(z, 75)[0],
        "min": nanmin(z, axis=0),
        "max": nanmax(z, axis=0)})


# --- Text and plots (print() and plot() methods of R)

@plot_method("plotband")
def tsx_plot_plotband(x, fig):
    cl = x["call"]
    co = tsx_time_coords(x["dates"], x["time"])
    ax = fig.add_subplot(1, 1, 1)
    data = np.asarray(x["data"])
    if not cl["all"]:
        lab = x["series"][0]
        if cl["overlay"]:
            title = "Series %s: Series plot every %d samples" % (lab, cl["s"])
            colors = tsx_rainbow(data.shape[1])
        else:
            title = "Series %s: Series Plot with 2*S.D. bands" % lab
            colors = [col("black")]
        for k in range(data.shape[1]):
            ax.plot(co["x"], data[:, k], color=colors[k % len(colors)], linewidth=1)
        ax.set_ylabel("Series " + lab)
        ax.axhline(x["mean"], color=col("red"))
        for b in (-2, 2):
            ax.axhline(x["mean"] + b * x["sd"], color=col("red"), linestyle=":")
    else:
        colors = tsx_dark3(data.shape[1])
        for k in range(data.shape[1]):
            ax.plot(co["x"], data[:, k], color=colors[k], linewidth=1, label=x["series"][k])
        ax.set_ylabel("Standard scale" if cl["standard"] else "Units")
        title = ("Standardised Plot of All Series with 2*S.D. bands" if cl["standard"]
                 else "Plot of All Series")
        if cl["standard"]:
            ax.axhline(0, color=col("red"))
            for b in (-2, 2):
                ax.axhline(b, color=col("red"), linestyle=":")
        ax.legend(loc="upper left", frameon=False, fontsize=8)
    tsx_xlim(ax, co["xlim"])
    tsx_ylim(ax, x["ylim"])
    ax.set_xlabel(co["lab"])
    ax.set_title(title)


def tsx_plot_boxstats(ax, xv, st, hv, title, xlab, ylab, labels=None):
    vals = np.r_[st["min"], st["max"], np.asarray(hv, dtype=float)]
    ax.plot(xv, st["mean"], color=col("red"), linewidth=2, label="Mean")
    ax.plot(xv, st["median"], color=col("black"), linewidth=2, label="Median")
    ax.plot(xv, st["p25"], ":", color=col("red"), label="25% and 75% Percentiles")
    ax.plot(xv, st["p75"], ":", color=col("red"))
    ax.plot(xv, st["min"], "*", color=col("blue"), linestyle="none",
            label="Maximum and Minimum")
    ax.plot(xv, st["max"], "*", color=col("blue"), linestyle="none")
    if len(hv):
        ax.plot(np.arange(1, len(hv) + 1), hv, "o-", color=col("black"), markersize=3)
    tsx_xlim(ax, 0, np.max(xv) + 1)
    tsx_ylim(ax, np.nanmin(vals), np.nanmax(vals))
    if labels is not None:
        ax.set_xticks(xv)
        ax.set_xticklabels(labels, rotation=90, fontsize=7)
    ax.set_xlabel(xlab)
    ax.set_ylabel(ylab)
    ax.set_title(title)
    ax.legend(loc="upper left", frameon=False, fontsize=8)


@plot_method("vboxplot")
def tsx_plot_vboxplot(x, fig):
    s = x["call"]["s"]
    dated = x["group_dates"] is not None
    ax = fig.add_subplot(1, 1, 1)
    tsx_plot_boxstats(ax, x["stats"]["group"].to_numpy(), x["stats"], x["highlight"],
                      "Series %s: Box Plot (every %d samples apart)" % (x["series"], s),
                      "Groups of %d samples (start date)" % s if dated
                      else "Groups of every %d samples apart" % s,
                      "Values of Series " + x["series"],
                      labels=tsx_format_dates(x["group_dates"]) if dated else None)
    fig.tight_layout()


@plot_method("vtboxplot")
def tsx_plot_vtboxplot(x, fig):
    s = x["call"]["s"]
    ax = fig.add_subplot(1, 1, 1)
    tsx_plot_boxstats(ax, x["stats"]["position"].to_numpy(), x["stats"], x["highlight"],
                      "Series %s: Transpose Box Plot (%d samples)" % (x["series"], s),
                      "Groups of %d samples" % s, "Values of Series " + x["series"])


@text_method("vboxplot")
def tsx_text_vboxplot(x, digits=None):
    digits = 4 if digits is None else digits
    st = x["stats"]
    if x["group_dates"] is not None:
        st = st.copy()
        st.insert(1, "start", tsx_format_dates(x["group_dates"]))
    return tsx_cat_block(
        title="Series %s: Box Plot (every %d samples apart)" % (x["series"], x["call"]["s"]),
        table=tsx_format_table(st, [0] + [digits] * (st.shape[1] - 1)))


@text_method("vtboxplot")
def tsx_text_vtboxplot(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(
        title="Series %s: Transpose Box Plot (%d samples, standardised)" % (x["series"],
                                                                             x["call"]["s"]),
        table=tsx_format_table(x["stats"], [0] + [digits] * 6))
