import math

import numpy as np
import pandas as pd

from ._result import text_method, tsx_result
from ._tables import tsx_tables
from ._utils_input import as_tsx_matrix
from ._utils_math import tsx_ols
from ._utils_print import tsx_cat_block, tsx_format_table

ADF_TABLES = ("t_none", "t_const", "t_trend", "f_const", "f_trend")


def adftest(y, lags=None, names=None):
    """Augmented Dickey-Fuller unit root tests.

    ADF regressions of :math:`z_t` on :math:`z_{t-1}`, :math:`p` lagged
    differences and the deterministic terms of three models: no constant
    and no trend, constant, and constant plus linear trend. The tests are
    the t statistics of :math:`H_0: \\rho = 1` and the F statistics
    :math:`\\Phi_1` (:math:`\\rho = 1` and no constant) and :math:`\\Phi_3`
    (:math:`\\rho = 1` and no trend).

    P-values are approximate, interpolated in the tables of Dickey and
    Fuller (see :func:`adfcritical`).

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    lags : int or list of int, optional
        Number(s) of lagged differences included in the regressions.
        Default: ``1..min(floor(sqrt(T)), 20)`` for one series and
        ``min(floor(sqrt(T)), 20)`` for several series. If the largest lag
        exceeds ``T / 2`` the test is computed only for ``floor(T / 2)``
        lags.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_adftest`` with fields ``call``, ``series``,
        ``n`` (sample size used for the p-values) and three DataFrames, one
        row per series and lag:

        * ``none``: ``series``, ``lag``, ``rho``, ``t``, ``p_t``,
        * ``const``: as ``none`` plus ``const``, ``t_const``, ``f``
          (:math:`\\Phi_1`), ``p_f``,
        * ``trend``: as ``const`` plus ``trend``, ``t_trend``, with ``f``
          being :math:`\\Phi_3`.

    See Also
    --------
    TsxResult.text, adfcritical, vphillips, johansentest

    References
    ----------
    Dickey, D.A. and Fuller, W.A. (1979). Distribution of the estimators for
    autoregressive time series with a unit root. *Journal of the American
    Statistical Association*, 74, 427-431.

    Dickey, D.A. and Fuller, W.A. (1981). Likelihood ratio statistics for
    autoregressive time series with a unit root. *Econometrica*, 49,
    1057-1072.

    Said, S.E. and Dickey, D.A. (1984). Testing for unit roots in
    autoregressive-moving average models of unknown order. *Biometrika*,
    71, 599-607.

    Examples
    --------
    >>> adftest(np.log(load_data("airpas")), lags=[1, 2, 3, 4])
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    lags = tsx_unitroot_lags(lags, n, m)
    none, const, trend = [], [], []
    for i in range(m):
        for p in lags:
            d = tsx_adf_design(y[:, i], p)
            extra = list(range(3, 3 + p))
            # No constant, no trend
            r0 = tsx_adf_ols(d["y"], d["x"][:, [0] + extra])
            none.append({"series": names[i], "lag": p, "rho": r0["beta"][0],
                         "t": (r0["beta"][0] - 1) / r0["se"][0]})
            # Constant
            r1 = tsx_adf_ols(d["y"], d["x"][:, [0, 1] + extra])
            vv = np.array([r1["beta"][0] - 1, r1["beta"][1]])
            f1 = float(vv @ np.linalg.solve(r1["cov"][:2, :2], vv)) / 2
            const.append({"series": names[i], "lag": p, "rho": r1["beta"][0],
                          "t": (r1["beta"][0] - 1) / r1["se"][0], "const": r1["beta"][1],
                          "t_const": r1["beta"][1] / r1["se"][1], "f": f1})
            # Constant and trend
            r2 = tsx_adf_ols(d["y"], d["x"])
            vv = np.array([r2["beta"][0] - 1, r2["beta"][2]])
            f3 = float(vv @ np.linalg.solve(r2["cov"][np.ix_([0, 2], [0, 2])], vv)) / 2
            trend.append({"series": names[i], "lag": p, "rho": r2["beta"][0],
                          "t": (r2["beta"][0] - 1) / r2["se"][0], "const": r2["beta"][1],
                          "t_const": r2["beta"][1] / r2["se"][1], "trend": r2["beta"][2],
                          "t_trend": r2["beta"][2] / r2["se"][2], "f": f3})
    none = pd.DataFrame(none)
    const = pd.DataFrame(const)
    trend = pd.DataFrame(trend)
    none["p_t"] = adfcritical(none["t"], n, "t_none")
    const["p_t"] = adfcritical(const["t"], n, "t_const")
    const["p_f"] = adfcritical(const["f"], n, "f_const")
    trend["p_t"] = adfcritical(trend["t"], n, "t_trend")
    trend["p_f"] = adfcritical(trend["f"], n, "f_trend")
    const = const[["series", "lag", "rho", "t", "p_t", "const", "t_const", "f", "p_f"]]
    trend = trend[["series", "lag", "rho", "t", "p_t", "const", "t_const", "trend", "t_trend",
                   "f", "p_f"]]
    return tsx_result("adftest", call={"lags": lags}, series=names, n=n, none=none,
                      const=const, trend=trend)


def tsx_unitroot_lags(lags, n, m):
    """Default and correction of the lags of the unit root tests
    (adftest(), vphillips(), johansentest())."""
    if lags is None or np.size(lags) == 0:
        lmax = min(math.floor(math.sqrt(n)), 20)
        lags = list(range(1, lmax + 1)) if m == 1 else [lmax]
    lags = [int(round(v)) for v in np.atleast_1d(lags)]
    if max(lags) > n / 2:
        lags = [n // 2]
    return lags


def tsx_adf_design(z, p):
    """Design of the ADF regressions with p lagged differences: columns
    z(t-1), constant, trend, dz(t-1), ..., dz(t-p). Rows with missing values
    are removed."""
    n = len(z)
    dz = np.diff(z)
    rows = np.arange(p + 1, n)
    cols = [z[rows - 1], np.ones(len(rows)), np.arange(1, len(rows) + 1, dtype=float)]
    for j in range(1, p + 1):
        cols.append(dz[rows - 1 - j])
    x = np.column_stack(cols)
    yy = z[rows]
    ok = ~np.isnan(x).any(axis=1) & ~np.isnan(yy)
    return {"y": yy[ok], "x": x[ok, :]}


def tsx_adf_ols(y, x):
    if x.shape[0] <= x.shape[1]:
        raise ValueError("Too many lags for the sample size; reduce 'lags'.")
    r = tsx_ols(y, x)
    s2 = r["sse"] / (x.shape[0] - x.shape[1])
    cov = s2 * r["ixx"]
    return {"beta": r["beta"], "cov": cov, "se": np.sqrt(np.diag(cov)), "e": r["e"],
            "sse": r["sse"], "s2": s2}


def adfcritical(x, n, table="t_none"):
    """Approximate p-values of Dickey-Fuller statistics.

    Interpolates the p-value of Dickey-Fuller t and F statistics in the
    tables of Fuller (1976) and Dickey and Fuller (1981). The critical
    values are first interpolated linearly in the sample size (clamped to
    25; sizes above 500 use the asymptotic row), then the p-value is
    interpolated linearly in the statistic. Outside the tables the p-value
    is set to 0 or 1.

    Parameters
    ----------
    x : float or array_like
        Statistics.
    n : int
        Sample size.
    table : str
        One of ``"t_none"``, ``"t_const"``, ``"t_trend"`` (t statistics
        without deterministic terms, with constant, with constant and
        trend), ``"f_const"`` (:math:`\\Phi_1`) or ``"f_trend"``
        (:math:`\\Phi_3`).

    Returns
    -------
    numpy.ndarray
        P-values.

    See Also
    --------
    adftest, vphillips

    Examples
    --------
    >>> adfcritical([-3.5, -2, 0], 100, "t_const")
    """
    if table not in ADF_TABLES:
        raise ValueError("'table' must be one of " + ", ".join('"%s"' % t for t in ADF_TABLES)
                         + ".")
    tb = tsx_tables()
    tab = tb["adf"][table]
    sizes = tb["adf_sizes"]
    is_t = table[0] == "t"
    p = tb["adf_p_t"] if is_t else tb["adf_p_f"]
    if n > 500:
        n = 1000
    if n < 25:
        n = 25
    # Points (critical value, sample size, probability) in column-major order
    px = tab.ravel(order="F")
    py = np.tile(sizes, len(p))
    pp = np.repeat(p, len(sizes))
    tri = tb["adf_tri"][table]
    x = np.atleast_1d(np.asarray(x, dtype=float))
    out = np.full(len(x), np.nan)
    for k, xi in enumerate(x):
        if np.isnan(xi):
            continue
        v = tsx_tri_interp(px, py, pp, tri, xi, n)
        if not np.isnan(v):
            out[k] = v
        elif is_t:
            out[k] = 1.0 if xi > -0.5 else 0.0
        else:
            out[k] = 0.0 if xi > 4 else 1.0
    return out


def tsx_tri_interp(px, py, pv, tri, x0, y0):
    """Linear interpolation on a triangulation: value at (x0, y0) from the
    barycentric coordinates of the first triangle that contains it; nan
    outside the convex hull."""
    i1, i2, i3 = tri[:, 0], tri[:, 1], tri[:, 2]
    x1, y1 = px[i1], py[i1]
    x2, y2 = px[i2], py[i2]
    x3, y3 = px[i3], py[i3]
    den = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
    w1 = ((y2 - y3) * (x0 - x3) + (x3 - x2) * (y0 - y3)) / den
    w2 = ((y3 - y1) * (x0 - x3) + (x1 - x3) * (y0 - y3)) / den
    w3 = 1 - w1 - w2
    tol = -1e-10
    inside = np.nonzero((w1 >= tol) & (w2 >= tol) & (w3 >= tol))[0]
    if len(inside) == 0:
        return np.nan
    k = inside[0]
    return float(w1[k] * pv[i1[k]] + w2[k] * pv[i2[k]] + w3[k] * pv[i3[k]])


# --- Text output (print() method of R)

@text_method("adftest")
def tsx_text_adftest(x, digits=None):
    d = 4 if digits is None else digits
    multi = len(set(x["none"]["series"])) > 1

    def rn(t):
        return list(t["series"]) if multi else None

    def drop(t):
        return t.drop(columns="series")

    out = tsx_cat_block(
        title="Augmented Dickey-Fuller Tests (NO CONSTANT, NO TREND)",
        notes=["T-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
               "P values are approximate based on tables"],
        table=tsx_format_table(drop(x["none"]), [0, d, d, d], row_names=rn(x["none"]),
                               col_names=["Lags", "z(t-1)", "T-Test", "P-value"]))
    out += [""] + tsx_cat_block(
        title="Augmented Dickey-Fuller Tests (CONSTANT, NO TREND)",
        notes=["T-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
               "F-Test (Phi1) is for H0: Rho= 1 and Ct= 0"],
        table=tsx_format_table(drop(x["const"]), [0] + [d] * 7, row_names=rn(x["const"]),
                               col_names=["Lags", "z(t-1)", "T-Test", "P-value", "Ct", "T-Test",
                                          "F-Test", "P-value"]))
    out += [""] + tsx_cat_block(
        title="Augmented Dickey-Fuller Tests (CONSTANT AND TREND)",
        notes=["T-Test for z(t-1) is H0: Rho= 1 (Series is integrated)",
               "F-Test (Phi3) is for H0: Rho= 1 and D= 0"],
        table=tsx_format_table(drop(x["trend"]), [0] + [d] * 9, row_names=rn(x["trend"]),
                               col_names=["Lags", "z(t-1)", "T-Test", "P-value", "Ct", "T-Test",
                                          "D", "T-Test", "F-Test", "P-value"]))
    return out
