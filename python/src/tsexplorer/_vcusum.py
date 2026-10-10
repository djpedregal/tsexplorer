import math

import numpy as np
import pandas as pd

from ._distribution import tsx_line_fit
from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_format_dates, tsx_series_index
from ._utils_math import nanmax, nanmean, nanmedian, nanmin, nansd, tsx_cumsum, tsx_mean, tsx_sd
from ._utils_plot import col, tsx_abline, tsx_time_coords, tsx_xlim, tsx_ylim
from ._utils_print import tsx_cat_block, tsx_format_table


def vcusum(y, series=1, names=None):
    """CUSUM and CUSUM of squares tests.

    Cumulative sums of the standardised series (CUSUM) and of its squared
    deviations from the mean (CUSUMSQ), with 5% confidence bands.

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
        Object of class ``tsx_vcusum`` with fields ``call``, ``series`` and
        ``table``, a DataFrame with columns ``t``, ``cusum``,
        ``cusum_lower``, ``cusum_upper``, ``cusumsq``, ``cusumsq_lower``,
        ``cusumsq_upper``, and ``dates`` (dates of the rows for dated
        inputs, otherwise ``None``).

    See Also
    --------
    TsxResult.plot, testhet, stdmean

    References
    ----------
    Brown, R.L., Durbin, J. and Evans, J.M. (1975). Techniques for testing
    the constancy of regression relationships over time. *Journal of the
    Royal Statistical Society B*, 37, 149-192.

    Examples
    --------
    >>> vcusum(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    """
    y, names, dates = as_tsx_matrix(y, names)
    n = y.shape[0]
    i = tsx_series_index(series, names)[0]
    z = y[:, i - 1]
    ok = ~np.isnan(z)
    zm = z[ok] - tsx_mean(z[ok])
    cusum = np.full(n, np.nan)
    cusumsq = np.full(n, np.nan)
    cusum[ok] = tsx_cumsum(zm / tsx_sd(z[ok]))
    cusumsq[ok] = tsx_cumsum(zm ** 2 / math.fsum(zm ** 2))
    t = np.arange(1, n + 1)
    band = 0.948 * math.sqrt(n) + 2 * 0.948 * t / math.sqrt(n)
    tab = pd.DataFrame({"t": t, "cusum": cusum, "cusum_lower": -band, "cusum_upper": band,
                        "cusumsq": cusumsq, "cusumsq_lower": -0.32894 + t / n,
                        "cusumsq_upper": 0.32894 + t / n})
    return tsx_result("vcusum", call={"series": i}, series=names[i - 1], table=tab,
                      dates=dates)


def stdmean(y, s=12, type=0, numbers=True, series=1, names=None):
    """Standard deviation - mean plots.

    Splits the series into groups of ``s`` consecutive observations (the
    first ``T mod s`` observations are discarded) and plots a dispersion
    measure against a location measure of each group, with the least
    squares line. A positive slope suggests a transformation to stabilise
    the variance.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    s : int
        Length of the groups (seasonal period). Default 12.
    type : int
        ``0``: standard deviation vs mean; ``1``: MEDA vs median; ``2``:
        range vs mean.
    numbers : bool
        Label each point with the number of its group in the plot.
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_stdmean`` with fields ``call``, ``series``,
        ``table`` (DataFrame with columns ``group``, ``location``,
        ``dispersion``) and ``coef`` (dict with the ``intercept`` and
        ``slope`` of the least squares line).

    See Also
    --------
    TsxResult.plot, vboxcox, meda

    Examples
    --------
    >>> stdmean(load_data("airpas"))
    >>> stdmean(np.log(load_data("airpas")), type=1)
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    s = tsx_check_int(s, "s", 2)
    i = tsx_series_index(series, names)[0]
    i0 = n % s + 1
    ng = (n - i0 + 1) // s
    if ng < 2:
        raise ValueError("Not enough data for groups of length 's'.")
    zi = y[i0 - 1:, i - 1].reshape((s, ng), order="F")
    if type == 0:
        loc = nanmean(zi, axis=0)
        disp = nansd(zi, axis=0)
    elif type == 1:
        loc = nanmedian(zi, axis=0)
        disp = np.array([nanmedian(np.abs(zi[:, k] - loc[k])) for k in range(ng)])
    else:
        loc = nanmean(zi, axis=0)
        disp = nanmax(zi, axis=0) - nanmin(zi, axis=0)
    b = tsx_line_fit(loc, disp)
    return tsx_result("stdmean", call={"s": s, "type": type, "numbers": numbers, "series": i},
                      series=names[i - 1],
                      table=pd.DataFrame({"group": np.arange(1, ng + 1), "location": loc,
                                          "dispersion": disp}),
                      coef={"intercept": float(b[0]), "slope": float(b[1])})


# --- Text and plots (print() and plot() methods of R)

@plot_method("vcusum")
def tsx_plot_vcusum(x, fig):
    t = x["table"]
    co = tsx_time_coords(x["dates"], t["t"].to_numpy())
    ax1, ax2 = fig.subplots(2, 1)
    ax1.plot(co["x"], t["cusum"], color=col("black"))
    ax1.plot(co["x"], t["cusum_lower"], ":", color=col("red"))
    ax1.plot(co["x"], t["cusum_upper"], ":", color=col("red"))
    ax1.axhline(0, color=col("red"))
    tsx_xlim(ax1, co["xlim"])
    ax1.set_ylabel("CUSUM test")
    ax1.set_title("Series %s: CUSUM test with 5%% Confidence Band" % x["series"])
    ax2.plot(co["x"], t["cusumsq"], color=col("black"))
    ax2.plot(co["x"], t["cusumsq_lower"], ":", color=col("red"))
    ax2.plot(co["x"], t["cusumsq_upper"], ":", color=col("red"))
    ax2.plot([co["x"][0], co["x"][-1]], [np.nanmin(t["cusumsq"]), np.nanmax(t["cusumsq"])],
             color=col("red"))
    tsx_xlim(ax2, co["xlim"])
    ax2.set_xlabel(co["lab"])
    ax2.set_ylabel("CUSUMSQ test")
    ax2.set_title("Series %s: CUSUMSQ test with 5%% Confidence Band" % x["series"])
    fig.tight_layout()


@text_method("vcusum")
def tsx_text_vcusum(x, digits=None):
    digits = 4 if digits is None else digits
    tab = x["table"]
    if x["dates"] is not None:
        tab = tab.copy()
        tab.insert(1, "date", tsx_format_dates(x["dates"]))
    return tsx_cat_block(title="Series %s: CUSUM and CUSUMSQ tests" % x["series"],
                         table=tsx_format_table(tab, [0] + [digits] * (tab.shape[1] - 1)))


@plot_method("stdmean")
def tsx_plot_stdmean(x, fig):
    lab = {0: ["Mean", "Standard Deviation", "Standard Deviation - Mean Plot"],
           1: ["Median", "MEDA", "MEDA - Median Plot"]}.get(
               x["call"]["type"], ["Mean", "Range", "Range - Mean Plot"])
    t = x["table"]
    ax = fig.add_subplot(1, 1, 1)
    ax.plot(t["location"], t["dispersion"], "o", color=col("blue"), markersize=4)
    tsx_abline(ax, x["coef"]["intercept"], x["coef"]["slope"], t["location"], color=col("red"))
    ax.set_xlabel(lab[0])
    ax.set_ylabel(lab[1])
    ax.set_title("Series %s: %s" % (x["series"], lab[2]))
    if x["call"]["numbers"]:
        lo, hi = ax.get_ylim()
        inc = (hi - lo) / 30
        for g, a, b in zip(t["group"], t["location"], t["dispersion"]):
            ax.text(a, b + inc, str(g), fontsize=8, ha="center")


@text_method("stdmean")
def tsx_text_stdmean(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(
        title="Series %s: dispersion vs location by groups of %d" % (x["series"], x["call"]["s"]),
        notes="Least squares line: intercept %.4f, slope %.4f" % (x["coef"]["intercept"],
                                                                  x["coef"]["slope"]),
        table=tsx_format_table(x["table"], [0, digits, digits],
                               col_names=["Group", "Location", "Dispersion"]))
