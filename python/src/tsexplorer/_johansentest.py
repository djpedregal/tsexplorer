import numpy as np
import pandas as pd

from ._adftest import tsx_unitroot_lags
from ._result import text_method, tsx_result
from ._tables import tsx_tables
from ._utils_input import as_tsx_matrix
from ._utils_math import tsx_delay, tsx_interpol, tsx_nanprod
from ._utils_print import tsx_cat_block, tsx_format_table


def _interleave(a, b, k):
    return np.column_stack([a, b]).ravel()[:k]


def johansentest(y, lags=None, names=None):
    """Johansen cointegration tests.

    Maximum eigenvalue and trace statistics of Johansen (1988) for the
    number of cointegrating relations of a VAR model in levels with ``lag``
    lags, under three specifications of the deterministic terms (none,
    constant, constant and linear trend). For one series the test is a unit
    root test.

    P-values are approximate, interpolated (and linearly extrapolated,
    clamped to ``[0, 1]``) in tables of critical values for up to 5
    non-stationary directions; beyond that they are ``nan``. The model
    without deterministic terms uses the tables of Osterwald-Lenum (1992,
    Table 0) and the model with an unrestricted constant those of Johansen
    and Juselius (1990, Table A1). There are no tables for the model with an
    unrestricted linear trend, whose p-values are ``nan``.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    lags : int or list of int, optional
        Lag order(s) of the VAR in levels (the VECM includes ``lag - 1``
        lagged differences). Default: ``2..min(floor(sqrt(T)), 20)`` for one
        series (lag 1 is removed) and ``min(floor(sqrt(T)), 20)`` for
        several.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_johansentest`` with fields ``call``,
        ``series`` and

        * ``table``: DataFrame with columns ``lag``, ``type`` (``"max"`` or
          ``"trace"``), ``h0``, ``h1`` (number of cointegrating relations
          under the null and the alternative), ``stat_none``, ``p_none``,
          ``stat_const``, ``p_const``, ``stat_trend``, ``p_trend``,
        * ``eigen``: DataFrame with columns ``lag``, ``i``, ``eigen_none``,
          ``lr_none``, ``eigen_const``, ``lr_const``, ``eigen_trend``,
          ``lr_trend`` (eigenvalues and :math:`-T \\log(1 - \\lambda_i)`).

    See Also
    --------
    TsxResult.text, adftest, vphillips

    References
    ----------
    Johansen, S. (1988). Statistical analysis of cointegration vectors.
    *Journal of Economic Dynamics and Control*, 12, 231-254.

    Johansen, S. and Juselius, K. (1990). Maximum likelihood estimation and
    inference on cointegration. *Oxford Bulletin of Economics and
    Statistics*, 52, 169-210.

    Osterwald-Lenum, M. (1992). A note with quantiles of the asymptotic
    distribution of the maximum likelihood cointegration rank test
    statistics. *Oxford Bulletin of Economics and Statistics*, 54, 461-472.

    Examples
    --------
    >>> johansentest(np.log(load_data("lydia_pinkham")))
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    lags = tsx_unitroot_lags(lags, n, m)
    if m == 1:
        lags = [v for v in lags if v != 1]
    if len(lags) == 0:
        raise ValueError("'lags' must include values greater than 1 for one series.")
    k = 2 * m - 1
    h0 = np.repeat(np.arange(m), 2)[:k]
    h1 = _interleave(np.arange(1, m + 1), np.full(m, m), k)
    type_ = np.array(["max", "trace"] * m)[:k]
    tabs = []
    eigs = []
    for lag in lags:
        res = [tsx_johansen_eigen(y, lag, det) for det in ("none", "const", "trend")]
        stat = [_interleave(r["lr"], np.cumsum(r["lr"][::-1])[::-1], k) for r in res]
        tl = pd.DataFrame({"lag": lag, "type": type_, "h0": h0, "h1": h1})
        # Critical value tables: dist = 1 is Osterwald-Lenum (1992) Table 0
        # (no deterministic terms), dist = 3 is Johansen-Juselius (1990) Table
        # A1 (unrestricted constant). No table for the unrestricted trend model.
        tl["stat_none"] = stat[0]
        tl["p_none"] = tsx_johansen_p(stat[0], m - h0, type_, 1)
        tl["stat_const"] = stat[1]
        tl["p_const"] = tsx_johansen_p(stat[1], m - h0, type_, 3)
        tl["stat_trend"] = stat[2]
        tl["p_trend"] = np.nan
        tabs.append(tl)
        eigs.append(pd.DataFrame({"lag": lag, "i": np.arange(1, m + 1),
                                  "eigen_none": res[0]["lambda"], "lr_none": res[0]["lr"],
                                  "eigen_const": res[1]["lambda"], "lr_const": res[1]["lr"],
                                  "eigen_trend": res[2]["lambda"], "lr_trend": res[2]["lr"]}))
    return tsx_result("johansentest", call={"lags": lags}, series=names,
                      table=pd.concat(tabs, ignore_index=True),
                      eigen=pd.concat(eigs, ignore_index=True))


def tsx_johansen_eigen(y, lag, det):
    """Eigenvalues of the reduced rank regression (Johansen 1988). det:
    "none", "const" or "trend"."""
    n, m = y.shape
    dz = np.diff(y, axis=0)
    lagy = tsx_delay(dz, range(lag)) if lag > 1 else dz
    tz = lagy.shape[0]
    x = lagy[:, m:]
    if det in ("const", "trend"):
        x = np.hstack([x, np.ones((tz, 1))])
    if det == "trend":
        x = np.hstack([x, np.arange(1, tz + 1, dtype=float).reshape(-1, 1)])
    dzt = lagy[:, :m]
    zlag = y[n - tz - 1:n - 1, :]
    if x.shape[1] > 0:
        ixx = np.linalg.inv(tsx_nanprod(x.T, x)[0])
        u = dzt - tsx_nanprod(x, ixx @ tsx_nanprod(x.T, dzt)[0])[0]
        v = zlag - tsx_nanprod(x, ixx @ tsx_nanprod(x.T, zlag)[0])[0]
    else:
        u = dzt
        v = zlag
    uu = tsx_nanprod(u.T, u)[0] / tz
    vv = tsx_nanprod(v.T, v)[0] / tz
    uv = tsx_nanprod(u.T, v)[0] / tz
    lam = np.real(np.linalg.eigvals(np.linalg.inv(vv) @ uv.T @ np.linalg.inv(uu) @ uv))
    lam = np.sort(lam)[::-1]
    return {"lambda": lam, "lr": -n * np.log(1 - lam)}


def tsx_johansen_p(x, g, type_, dist):
    """Approximate p-values of the Johansen statistics. g: number of
    non-stationary directions (m - h0); type "max" or "trace"; dist: 1, 2 or
    3 (tables of the three deterministic specifications)."""
    tb = tsx_tables()
    x = np.atleast_1d(np.asarray(x, dtype=float))
    g = np.atleast_1d(g)
    type_ = np.atleast_1d(type_)
    out = np.full(len(x), np.nan)
    for i in range(len(x)):
        if g[i] > 5 or np.isnan(x[i]):
            continue
        tab = tb["joh"]["%s_%d" % (type_[i], dist)]
        out[i] = tsx_interpol(tab[int(g[i]) - 1, :], tb["joh_p"], x[i], (0, 1))
    return out


# --- Text output (print() method of R)

@text_method("johansentest")
def tsx_text_johansentest(x, digits=None):
    d = 4 if digits is None else digits
    t = x["table"]
    multi = len(x["series"]) > 1
    if multi:
        hh = ["h= %d  -  h= %d" % (a, b) for a, b in zip(t["h0"], t["h1"])]
    else:
        hh = ["Lags %d" % v for v in t["lag"]]
    lines = tsx_format_table(t[["stat_none", "p_none", "stat_const", "p_const", "stat_trend",
                                "p_trend"]], d, row_names=hh,
                             col_names=["Stat1", "P-value", "Stat2", "P-value", "Stat3",
                                        "P-value"])
    title = "Johansen Cointegration Tests"
    if multi:
        title += " (lags= %s)" % ", ".join(str(v) for v in dict.fromkeys(t["lag"]))
    notes = (["'h' is the number of cointegrated relations"] if multi else []) + [
        "Stat1: test statistic based on model without deterministic parts",
        "Stat2: test statistic based on model including a constant term",
        "Stat3: test statistic based on model including a constant and linear trend",
        "Critical values are approximate based on tables",
        "(no tables available for Stat3: P-values are NA)"]
    out = tsx_cat_block(title=title, notes=notes, table=lines)
    if multi:
        out += [""] + tsx_cat_block(table=tsx_format_table(
            x["eigen"].iloc[:, 1:], [0] + [d] * 6,
            col_names=["i", "Eigen1", "-T[1-l(i)]", "Eigen2", "-T[1-l(i)]", "Eigen3",
                       "-T[1-l(i)]"]))
    return out
