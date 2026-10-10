import math

import numpy as np
import pandas as pd

from ._adftest import adfcritical, tsx_adf_design, tsx_adf_ols, tsx_unitroot_lags
from ._result import text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int
from ._utils_print import tsx_cat_block, tsx_format_table


def vphillips(y, lags=None, ncovs=None, names=None):
    """Phillips-Perron unit root tests.

    Phillips-Perron :math:`Z_t` statistics computed on the same three
    regressions as :func:`adftest` (no deterministic terms, constant,
    constant and trend, each one including ``lag`` lagged differences). The
    long run variance of the residuals is estimated with a Bartlett
    (Newey-West) window with ``ncovs`` autocovariances.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    lags : int or list of int, optional
        Number(s) of lagged differences included in the regressions (see
        :func:`adftest`).
    ncovs : int, optional
        Number of autocovariances of the residuals in the long run variance.
        Default ``floor(4 * (T / 100)^0.25)``.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vphillips`` with fields ``call``, ``series``,
        ``n`` and the DataFrames ``none``, ``const`` and ``trend`` with
        columns ``series``, ``lag``, ``rho``, ``z_t`` (Phillips-Perron
        statistic) and ``p_value``.

    See Also
    --------
    TsxResult.text, adftest, adfcritical

    References
    ----------
    Phillips, P.C.B. and Perron, P. (1988). Testing for a unit root in time
    series regression. *Biometrika*, 75, 335-346.

    Newey, W.K. and West, K.D. (1987). A simple, positive semi-definite,
    heteroskedasticity and autocorrelation consistent covariance matrix.
    *Econometrica*, 55, 703-708.

    Examples
    --------
    >>> vphillips(np.log(load_data("airpas")), lags=[1, 2, 3])
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    lags = tsx_unitroot_lags(lags, n, m)
    if ncovs is None:
        ncovs = math.floor(4 * (n / 100) ** 0.25)
    ncovs = tsx_check_int(ncovs, "ncovs", 0)
    out = {"none": [], "const": [], "trend": []}
    cols = {"none": [0], "const": [0, 1], "trend": [0, 1, 2]}
    for i in range(m):
        for p in lags:
            d = tsx_adf_design(y[:, i], p)
            for mod in cols:
                r = tsx_adf_ols(d["y"], d["x"][:, cols[mod] + list(range(3, 3 + p))])
                tstat = (r["beta"][0] - 1) / r["se"][0]
                z = tsx_pp_correction(tstat, r["e"], r["sse"], r["s2"], r["se"][0], n, ncovs)
                out[mod].append({"series": names[i], "lag": p, "rho": r["beta"][0], "z_t": z})
    tabs = {"none": "t_none", "const": "t_const", "trend": "t_trend"}
    res = {}
    for mod in out:
        d = pd.DataFrame(out[mod])
        d["p_value"] = adfcritical(d["z_t"], n, tabs[mod])
        res[mod] = d
    return tsx_result("vphillips", call={"lags": lags, "ncovs": ncovs}, series=names, n=n,
                      none=res["none"], const=res["const"], trend=res["trend"])


def tsx_pp_correction(tstat, e, sse, s2, se_rho, n, ncovs):
    """Phillips-Perron correction of the t statistic. nw: long run variance
    (Bartlett window); g0: residual variance (both divided by the full
    sample size T)."""
    nw = sse
    ne = len(e)
    for k in range(1, ncovs + 1):
        if k >= ne:
            break
        nw = nw + 2 * (1 - k / (ncovs + 1)) * np.sum(e[:ne - k] * e[k:])
    nw = nw / n
    g0 = sse / n
    return (math.sqrt(g0 / nw) * tstat - 0.5 * (nw - g0) / math.sqrt(nw) * n * se_rho
            / math.sqrt(s2))


# --- Text output (print() method of R)

@text_method("vphillips")
def tsx_text_vphillips(x, digits=None):
    d = 4 if digits is None else digits
    multi = len(x["series"]) > 1
    titles = {"none": "Phillips-Perron Tests (NO CONSTANT, NO TREND)",
              "const": "Phillips-Perron Tests (CONSTANT, NO TREND)",
              "trend": "Phillips-Perron Tests (CONSTANT AND TREND)"}
    out = []
    for mod, title in titles.items():
        t = x[mod]
        notes = None
        if mod == "none":
            notes = ["Number of residual covs= %d" % x["call"]["ncovs"],
                     "PP-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
                     "P values are approximate based on tables"]
        out += tsx_cat_block(
            title=title, notes=notes,
            table=tsx_format_table(t.drop(columns="series"), [0, d, d, d],
                                   row_names=list(t["series"]) if multi else None,
                                   col_names=["Lags", "z(t-1)", "PP-Test", "P-value"]))
        out.append("")
    return out
