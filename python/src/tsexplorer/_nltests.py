import math

import numpy as np
import pandas as pd
from scipy import linalg, stats

from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_series_index
from ._utils_math import tsx_acf_pacf, tsx_delay, tsx_ols, tsx_signif_marks
from ._utils_plot import tsx_plot_correlogram
from ._utils_print import tsx_cat_block, tsx_format_table


def nltests(y, ncoef=None, series=1, names=None):
    """Non-linearity tests based on squares.

    McLeod-Li (portmanteau on the ACF of the squared series), Monti (on the
    PACF of the squares) and Pena-Rodriguez (determinant of the
    autocorrelation matrix of the squares) tests.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    ncoef : int, optional
        Number of lags. Default ``min(38, ceil(T / 4 / m * 2))``.
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_nltests`` with fields ``call``, ``series`` and
        ``table``, a DataFrame with columns ``lag``, ``acf``, ``se_acf``,
        ``q_mll``, ``p_mll``, ``pacf``, ``se_pacf``, ``q_mt``, ``p_mt``,
        ``d_pr``, ``p_pr`` (statistics and p-values of the three tests for
        each lag).

    See Also
    --------
    TsxResult.text, TsxResult.plot, vtsay, varsbc2, vbds

    References
    ----------
    McLeod, A.I. and Li, W.K. (1983). Diagnostic checking ARMA time series
    models using squared-residual autocorrelations. *Journal of Time Series
    Analysis*, 4, 269-273.

    Monti, A.C. (1994). A proposal for a residual autocorrelation test in
    linear models. *Biometrika*, 81, 776-780.

    Pena, D. and Rodriguez, J. (2002). A powerful portmanteau test of lack
    of fit for time series. *Journal of the American Statistical
    Association*, 97, 601-610.

    Examples
    --------
    >>> nltests(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]), ncoef=12)
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    if ncoef is None:
        ncoef = min(38, math.ceil(n / 4 / m * 2))
    ncoef = min(tsx_check_int(ncoef, "ncoef"), n - 5)
    i = tsx_series_index(series, names)[0]
    r = tsx_acf_pacf(y[:, i - 1] ** 2, ncoef, 0)
    lags = np.arange(1, ncoef + 1)
    rk = np.sqrt((n + 2) / (n - lags)) * r["sacf"]
    d = np.zeros(ncoef)
    for k in lags:
        rm = linalg.toeplitz(np.r_[1.0, rk[:k]])
        d[k - 1] = -(n / (k + 1)) * np.log(abs(np.linalg.det(rm)))
    pd_ = stats.gamma.sf(d, a=3 * lags * (lags + 1) / (8 * lags + 4),
                         scale=3 * lags / (4 * lags + 2))
    tab = pd.DataFrame({"lag": lags, "acf": r["sacf"], "se_acf": r["se_acf"], "q_mll": r["q"],
                        "p_mll": r["p_q"], "pacf": r["spacf"], "se_pacf": r["se_pacf"],
                        "q_mt": r["q_mt"], "p_mt": r["p_q_mt"], "d_pr": d, "p_pr": pd_})
    return tsx_result("nltests", call={"ncoef": ncoef, "series": i}, series=names[i - 1],
                      table=tab)


def vtsay(y, lags=4, names=None):
    """Tsay (1986) non-linearity test.

    Tsay (1986) F test: the residuals :math:`e_t` of an AR(``lags``) model
    with constant are regressed on the cross products :math:`z_{t-i}
    z_{t-j}` (:math:`i \\le j`), previously orthogonalised with respect to
    the constant and the lags. With :math:`k = p(p+1)/2` products and
    :math:`n` observations,
    :math:`F = \\frac{(\\sum e_t^2 - \\sum \\varepsilon_t^2) / k}{\\sum
    \\varepsilon_t^2 / (n - p - k - 1)}` follows an :math:`F(k, n - p - k -
    1)` distribution under linearity. Missing values remove the
    corresponding rows.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    lags : int
        Order of the AR model (at least 2). Default 4.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vtsay`` with fields ``call``, ``series``,
        ``table`` (DataFrame with columns ``series``, ``f``, ``df1``,
        ``df2``, ``p_value``) and ``regressions`` (DataFrame with the
        auxiliary regression of the AR residuals on the orthogonalised
        products: ``series``, ``variable``, ``beta``, ``t``, ``p_value``, two
        sided).

    See Also
    --------
    TsxResult.text, nltests, vbds

    References
    ----------
    Tsay, R.S. (1986). Nonlinearity tests for time series. *Biometrika*,
    73, 461-466.

    Examples
    --------
    >>> vtsay(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    """
    y, names, _ = as_tsx_matrix(y, names)
    m = y.shape[1]
    lags = max(2, max(int(round(v)) for v in np.atleast_1d(lags)))
    labs = ["z(t-%d)*z(t-%d)" % (i, j) for i in range(1, lags + 1)
            for j in range(i, lags + 1)]
    kk = lags * (lags + 1) // 2
    f_ = np.full(m, np.nan)
    df2_ = np.full(m, np.nan)
    p_ = np.full(m, np.nan)
    regs = []
    for s in range(m):
        x = tsx_delay(y[:, s], range(lags + 1))
        x = x[~np.isnan(x).any(axis=1), :]
        n = x.shape[0]
        xl = np.column_stack([np.ones(n), x[:, 1:]])
        e = tsx_ols(x[:, 0], xl)["e"]
        xx = np.column_stack([tsx_ols(xl[:, i] * xl[:, j], xl)["e"]
                              for i in range(1, lags + 1) for j in range(i, lags + 1)])
        r = tsx_ols(e, xx)
        df2 = n - lags - kk - 1
        if df2 < 1:
            raise ValueError("Too few observations for the Tsay test with %d lags." % lags)
        s2 = r["sse"] / df2
        f = ((np.sum(e ** 2) - r["sse"]) / kk) / s2
        t = r["beta"] / np.sqrt(np.diag(s2 * r["ixx"]))
        f_[s] = f
        df2_[s] = df2
        p_[s] = stats.f.sf(f, kk, df2)
        regs.append(pd.DataFrame({"series": names[s], "variable": labs, "beta": r["beta"],
                                  "t": t, "p_value": 2 * stats.t.cdf(-np.abs(t), df2)}))
    tab = pd.DataFrame({"series": names, "f": f_, "df1": float(kk), "df2": df2_,
                        "p_value": p_})
    return tsx_result("vtsay", call={"lags": lags}, series=names, table=tab,
                      regressions=pd.concat(regs, ignore_index=True))


# --- Text and plots (print() and plot() methods of R)

@text_method("nltests")
def tsx_text_nltests(x, digits=None):
    d = 4 if digits is None else digits
    t = x["table"]
    lines = tsx_format_table(
        [t["lag"].to_numpy(), t["acf"].to_numpy(), tsx_signif_marks(t["acf"] / t["se_acf"]),
         t["q_mll"].to_numpy(), t["p_mll"].to_numpy(), t["pacf"].to_numpy(),
         tsx_signif_marks(t["pacf"] / t["se_pacf"]), t["q_mt"].to_numpy(), t["p_mt"].to_numpy(),
         t["d_pr"].to_numpy(), t["p_pr"].to_numpy()],
        [0, d, 0, d, d, d, 0, d, d, d, d],
        col_names=["Lag", "SACF", "", "MLL", "P-value", "SPACF", "", "MT", "P-value", "PR",
                   "P-value"])
    return tsx_cat_block(title="Non-Linearity Tests",
                         notes=["MLL: McLeod & Li (1983) Test", "MT:  Monti (1994) Test",
                                "PR:  Peña & Rodriguez (2002) Test",
                                "H0:  Process is Linear", "Series " + x["series"]],
                         table=lines)


@plot_method("nltests")
def tsx_plot_nltests(x, fig):
    t = x["table"]
    tsx_plot_correlogram(
        fig, t["lag"].to_numpy(), t[["acf", "pacf"]].to_numpy(),
        t[["se_acf", "se_pacf"]].to_numpy(), int(t["lag"].max()) + 2,
        ["Series %s: Sample Autocorrelation Function of Squared Data" % x["series"],
         "Series %s: Sample Partial Autocorrelation Function of Squared Data" % x["series"]])


@text_method("vtsay")
def tsx_text_vtsay(x, digits=None):
    d = 4 if digits is None else digits
    out = tsx_cat_block(title=["Tsay(1986) Non-Linear Test", "H0: Process is linear"],
                        notes="Summary table based on an AR(%d) Model:" % x["call"]["lags"],
                        table=tsx_format_table(x["table"].iloc[:, 1:], [d, 0, 0, d],
                                               row_names=x["series"],
                                               col_names=["Tsay-F", "DoF1", "DoF2", "P-value"]))
    out += ["", "Auxiliary Regressions:"]
    regs = x["regressions"]
    for s in x["series"]:
        r = regs[regs["series"] == s]
        out += tsx_cat_block(title="Series: " + s,
                             table=tsx_format_table(r[["beta", "t", "p_value"]], d,
                                                    row_names=list(r["variable"]),
                                                    col_names=["Betas", "T", "P-value"]))
    return out
