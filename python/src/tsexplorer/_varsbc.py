import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_series_index
from ._utils_math import nanmean, tsx_auxvarsbc, tsx_det
from ._utils_plot import col, tsx_xlim, tsx_ylim
from ._utils_print import tsx_cat_block, tsx_format_table, tsx_series_text


def varsbc(y, ncoef=None, series=1, names=None):
    """Information criteria of AR and VAR models.

    Corrected Akaike (AICc), Schwarz (SBC) and Hannan-Quinn (HQC) information
    criteria of AR (one series) or VAR (several series) models of orders
    ``0..ncoef``, and the likelihood ratio test of each order against the
    previous one.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    ncoef : int, optional
        Maximum order. Default ``min(38, ceil(T / 4 / m * 2))``, limited to
        ``T - 3``.
    series : int, str or list
        Series to analyse: one series (number from 1 or name) for AR models,
        several or ``"all"`` for a VAR model.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_varsbc`` with fields ``call``, ``series``
        (list with the series analysed), ``table`` (DataFrame with columns
        ``lag``, ``aicc``, ``sbc``, ``hqc``, ``chi``, ``p_chi``) and ``best``
        (dict with the order minimising each criterion).

    See Also
    --------
    TsxResult.text, TsxResult.plot, vident2, varsbc2

    References
    ----------
    Lütkepohl, H. (2005). *New Introduction to Multiple Time Series
    Analysis*. Springer.

    Examples
    --------
    >>> r = varsbc(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]), ncoef=15)
    >>> r.best
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    if ncoef is None:
        ncoef = min(38, math.ceil(n / 4 / m * 2))
    ncoef = min(tsx_check_int(ncoef, "ncoef", 0), n - 3)
    sel = tsx_series_index(series, names, allow_all=True)
    k = len(sel)
    zs = y[:, [i - 1 for i in sel]]
    zm = zs - nanmean(zs, axis=0)
    det_sa = tsx_det(zm.T @ zm / n)
    aicc = np.full(ncoef + 1, np.nan)
    sbc = np.full(ncoef + 1, np.nan)
    hqc = np.full(ncoef + 1, np.nan)
    chi = np.full(ncoef + 1, np.nan)
    for i in range(ncoef + 1):
        a = tsx_auxvarsbc(zm, i)
        aicc[i] = a["aicc"]
        sbc[i] = a["sbc"]
        hqc[i] = a["hqc"]
        det_s = tsx_det(a["sigma"])
        with np.errstate(all="ignore"):
            chi[i] = -(n - i - 1 - 0.5 - k * i) * np.log(det_s / det_sa)
        det_sa = det_s
    p_chi = stats.chi2.sf(chi, k * k)
    chi[0] = np.nan
    p_chi[0] = np.nan
    tab = pd.DataFrame({"lag": np.arange(ncoef + 1), "aicc": aicc, "sbc": sbc, "hqc": hqc,
                        "chi": chi, "p_chi": p_chi})
    best = {"aicc": int(np.nanargmin(aicc)), "sbc": int(np.nanargmin(sbc)),
            "hqc": int(np.nanargmin(hqc))}
    return tsx_result("varsbc", call={"ncoef": ncoef, "series": sel},
                      series=[names[i - 1] for i in sel], table=tab, best=best)


def varsbc2(y, ncoef=None, series=1, names=None):
    """Non-linearity test based on the Schwarz criterion of squares.

    Schwarz information criterion of AR models of orders ``0..ncoef`` fitted
    to the squares of the series. A minimum at order 0 suggests linearity.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    ncoef : int, optional
        Maximum order. Default ``min(38, ceil(sqrt(T)))``, limited to
        ``T - 3``.
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_varsbc2`` with fields ``call``, ``series``,
        ``table`` (DataFrame with columns ``lag`` and ``sbc``), ``best``
        (order with minimum SBC) and ``linear`` (``True`` when ``best`` is
        0).

    See Also
    --------
    TsxResult.plot, varsbc, nltests

    Examples
    --------
    >>> varsbc2(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    if ncoef is None:
        ncoef = min(38, math.ceil(math.sqrt(n)))
    ncoef = min(tsx_check_int(ncoef, "ncoef", 0), n - 3)
    i = tsx_series_index(series, names)[0]
    z2 = y[:, i - 1] ** 2
    zm = (z2 - nanmean(z2)).reshape(-1, 1)
    sbc = np.array([tsx_auxvarsbc(zm, k)["sbc"] for k in range(ncoef + 1)])
    best = int(np.nanargmin(sbc))
    return tsx_result("varsbc2", call={"ncoef": ncoef, "series": i}, series=names[i - 1],
                      table=pd.DataFrame({"lag": np.arange(ncoef + 1), "sbc": sbc}),
                      best=best, linear=best == 0)


# --- Text and plots (print() and plot() methods of R)

def tsx_series_label(series):
    series = tsx_series_text(series)
    if len(series) > 1:
        return ", ".join(series) + " (VAR model)"
    return series[0]


@text_method("varsbc")
def tsx_text_varsbc(x, digits=None):
    digits = 4 if digits is None else digits
    b = x["best"]
    return tsx_cat_block(
        title=["Identification Criteria", "Series " + tsx_series_label(x["series"])],
        notes=["AICc(%d): Corrected Akaike Information Criterion" % b["aicc"],
               "SBC(%d): Schwarz Information Criterion" % b["sbc"],
               "HQC(%d): Hannan and Quinn Criterion" % b["hqc"],
               "CHI: Likelihood ratio test of order k vs order k-1"],
        table=tsx_format_table(x["table"], [0] + [digits] * 5,
                               col_names=["Lag", "AICc", "SBC", "HQC", "CHI", "P-CHI"]))


@plot_method("varsbc")
def tsx_plot_varsbc(x, fig):
    t = x["table"]
    b = x["best"]
    ax1, ax2 = fig.subplots(2, 1, sharex=True, gridspec_kw={"height_ratios": [3, 1]})
    for key, c, lab in (("aicc", "blue", "AICc"), ("sbc", "darkgreen", "SBC"),
                        ("hqc", "red", "HQC")):
        ax1.plot(t["lag"], t[key], "*-", color=col(c), label="%s(%d)" % (lab, b[key]))
    ax1.grid(axis="y", linestyle=":")
    ax1.legend(loc="upper right", frameon=False)
    ax1.set_ylabel("Information Criteria")
    ax1.set_title("Series %s: Information Criteria of AR Models" % tsx_series_label(x["series"]))
    p = t["p_chi"].to_numpy()
    ymax = np.nanmax(p) if np.all(p[~np.isnan(p)] > 0.3) else 0.3
    ax2.plot(t["lag"], p, "*-", color=col("black"))
    ax2.axhline(0.05, color=col("red"), linestyle=":")
    ax2.axhline(0.1, color=col("blue"), linestyle=":")
    tsx_ylim(ax2, 0, ymax)
    ax2.set_xlabel("lags")
    ax2.set_ylabel("P-Chi")
    fig.tight_layout()


@text_method("varsbc2")
def tsx_text_varsbc2(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(
        title=["SBC Criterion of Squared Data", "Series " + x["series"]],
        notes="Minimum at lag %d: Process is %s" % (x["best"],
                                                    "Linear" if x["linear"] else "Non-Linear"),
        table=tsx_format_table(x["table"], [0, digits], col_names=["Lag", "SBC"]))


@plot_method("varsbc2")
def tsx_plot_varsbc2(x, fig):
    t = x["table"]
    ax = fig.add_subplot(1, 1, 1)
    ax.plot(t["lag"], t["sbc"], "*-", color=col("blue"))
    ax.grid(axis="y", linestyle=":")
    ax.set_xlabel("lags")
    ax.set_ylabel("SBC")
    ax.set_title("Series %s: SBC Criterion of Squared data (Min is %d: Process is %s"
                 % (x["series"], x["best"], "Linear)" if x["linear"] else "Non-Linear)"))
