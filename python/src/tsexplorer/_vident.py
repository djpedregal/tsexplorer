import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_series_index
from ._utils_math import (nanmean, tsx_acf_pacf, tsx_det, tsx_mvar, tsx_nancorr,
                          tsx_nancov, tsx_nanprod, tsx_signif_marks, tsx_standardize)
from ._utils_plot import tsx_plot_correlogram
from ._utils_print import tsx_cat_block, tsx_fmt_f, tsx_format_table, tsx_sprintf_f


def vident(y, ncoef=None, s=12, npar=0, series=1, names=None):
    """Sample autocorrelation and partial autocorrelation functions.

    Univariate sample ACF and PACF of one series, with their standard errors
    (Bartlett for the ACF, :math:`1/\\sqrt{T}` for the PACF), the Ljung-Box
    portmanteau test on the ACF and the Monti (1994) test on the PACF.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    ncoef : int, optional
        Number of lags. Default ``min(38, ceil(T / 4 / m * 2))``, limited to
        ``T - 5``.
    s : int
        Seasonal period, only used to highlight the seasonal lags in the
        plot.
    npar : int
        Number of estimated parameters when ``y`` is a set of residuals; the
        degrees of freedom of the portmanteau tests are ``lag - npar``.
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vident`` with fields ``call``, ``series`` (name
        of the series analysed) and ``table``, a DataFrame with columns
        ``lag``, ``acf``, ``se_acf``, ``q_lb``, ``p_lb``, ``pacf``,
        ``se_pacf``, ``q_mt``, ``p_mt``.

    See Also
    --------
    TsxResult.text, TsxResult.plot, vident2, nltests

    References
    ----------
    Ljung, G.M. and Box, G.E.P. (1978). On a measure of lack of fit in time
    series models. *Biometrika*, 65, 297-303.

    Monti, A.C. (1994). A proposal for a residual autocorrelation test in
    linear models. *Biometrika*, 81, 776-780.

    Examples
    --------
    >>> r = vident(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    >>> r.table.head()
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    if ncoef is None:
        ncoef = min(38, math.ceil(n / 4 / m * 2))
    ncoef = min(tsx_check_int(ncoef, "ncoef"), n - 5)
    if ncoef < 1:
        raise ValueError("Too few data points.")
    i = tsx_series_index(series, names)[0]
    r = tsx_acf_pacf(y[:, i - 1], ncoef, npar)
    tab = pd.DataFrame({"lag": np.arange(1, ncoef + 1), "acf": r["sacf"],
                        "se_acf": r["se_acf"], "q_lb": r["q"], "p_lb": r["p_q"],
                        "pacf": r["spacf"], "se_pacf": r["se_pacf"], "q_mt": r["q_mt"],
                        "p_mt": r["p_q_mt"]})
    return tsx_result("vident", call={"ncoef": ncoef, "s": s, "npar": npar, "series": i},
                      series=names[i - 1], table=tab)


def vident2(y, ncoef=None, s=12, npar=0, type=0, names=None):
    """Multivariate sample autocorrelation functions.

    Sample autocorrelation matrices and partial lag autocorrelation matrices
    (Heyse and Wei, 1985) or partial autoregression matrices (Tiao and Box,
    1981) of a vector of time series, together with the information
    criteria, the likelihood ratio statistic of adding one lag to a VAR
    model and a multivariate portmanteau test.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`), at least two series.
    ncoef : int, optional
        Number of lags. Default ``min(38, ceil(T / 4 / m * 2))``.
    s : int
        Seasonal period (only for plots).
    npar : int
        Number of estimated parameters (if ``y`` are residuals); the degrees
        of freedom of the portmanteau test are ``m^2 (lag - npar)``.
    type : int
        ``0`` for partial lag autocorrelation matrices, ``1`` for partial
        autoregression matrices.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vident2`` with fields

        * ``call``, ``series``,
        * ``acf``, ``se_acf``, ``pacf``, ``se_pacf``: arrays ``m x m x
          (ncoef + 1)`` for lags ``0..ncoef``. Element ``[a, b, k]`` is the
          correlation between series ``a`` at time ``t`` and series ``b`` at
          time ``t - k``. At lag 0 the partial matrices repeat the
          correlation matrix,
        * ``stats``: DataFrame with columns ``lag``, ``aic``, ``sbc``,
          ``chi``, ``p_chi`` (likelihood ratio test of a VAR(lag) against a
          VAR(lag - 1)), ``p_q`` (multivariate portmanteau test of Hosking
          (1980) with the correction of Li and McLeod (1981),
          :math:`T \\sum_k tr(R_k' R_0^{-1} R_k R_0^{-1}) + m^2 k (k + 1) /
          (2T)`) and ``det_sigma``.

    See Also
    --------
    TsxResult.text, TsxResult.plot, vident, varsbc

    References
    ----------
    Tiao, G.C. and Box, G.E.P. (1981). Modeling multiple time series with
    applications. *Journal of the American Statistical Association*, 76,
    802-816.

    Heyse, J.F. and Wei, W.W.S. (1985). The partial lag autocorrelation
    function. Technical Report 32, Temple University.

    Hosking, J.R.M. (1980). The multivariate portmanteau statistic. *Journal
    of the American Statistical Association*, 75, 602-608.

    Li, W.K. and McLeod, A.I. (1981). Distribution of the residual
    autocorrelations in multivariate ARMA time series models. *Journal of
    the Royal Statistical Society B*, 43, 231-239.

    Examples
    --------
    >>> r = vident2(vdif(np.log(load_data("lydia_pinkham"))), ncoef=8)
    >>> r.stats
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    if m < 2:
        raise ValueError("'vident2' needs at least two series.")
    if ncoef is None:
        ncoef = min(38, math.ceil(n / 4 / m * 2))
    ncoef = min(tsx_check_int(ncoef, "ncoef"), n - 5, n - 3)
    miss = bool(np.isnan(y).any())
    zs = tsx_standardize(y)
    z = y - nanmean(y, axis=0)
    det_sa = tsx_det(z.T @ z / n)
    acf = np.zeros((m, m, ncoef + 1))
    pacf = np.full((m, m, ncoef + 1), np.nan)
    se_acf = np.zeros((m, m, ncoef + 1))
    se_pacf = np.full((m, m, ncoef + 1), np.nan)
    r0 = tsx_nancov(zs)
    r0i = np.linalg.inv(r0)
    acf[:, :, 0] = r0
    pacf[:, :, 0] = r0
    se_acf[:, :, 0] = 1 / math.sqrt(n)
    se_pacf[:, :, 0] = 1 / math.sqrt(n)
    ss = np.sqrt(np.sum(z ** 2, axis=0))
    for k in range(1, ncoef + 1):
        if miss:
            prod, cnt = tsx_nanprod(zs[k:, :].T, zs[:n - k, :])
            acf[:, :, k] = prod / cnt
        else:
            acf[:, :, k] = (z[k:, :].T @ z[:n - k, :]) / np.outer(ss, ss)
        se_acf[:, :, k] = 1 / math.sqrt(n - k)
    if type == 0:
        se_pacf[:, :, 1:] = 1 / math.sqrt(n)
        pacf[:, :, 1] = acf[:, :, 1]
    st = pd.DataFrame({"lag": np.arange(1, ncoef + 1), "aic": np.nan, "sbc": np.nan,
                       "chi": np.nan, "p_chi": np.nan, "p_q": np.nan, "det_sigma": np.nan})
    aic = np.full(ncoef, np.nan)
    sbc = np.full(ncoef, np.nan)
    chi = np.full(ncoef, np.nan)
    p_q = np.full(ncoef, np.nan)
    det_sigma = np.full(ncoef, np.nan)
    cumtr = 0.0
    for i in range(1, ncoef + 1):
        v = tsx_mvar(z, range(1, i + 1), const=True)
        if type == 1:
            idx = slice((i - 1) * m, i * m)
            pacf[:, :, i] = v["p"][idx, :].T
            se_pacf[:, :, i] = v["se_p"][idx, :].T
        elif i < ncoef:
            vb = tsx_mvar(z, range(1, i + 1), const=True, partial=True)
            u = v["e"][v["e"].shape[0] - vb["e"].shape[0]:, :]
            cr = tsx_nancorr(np.hstack([u, vb["e"]]))
            pacf[:, :, i + 1] = cr[:m, m:2 * m]
        det_s = tsx_det(v["sigma"])
        aic[i - 1] = v["aic"]
        sbc[i - 1] = v["sbc"]
        chi[i - 1] = -(n - i - 1 - 0.5 - m * i) * np.log(det_s / det_sa)
        det_sigma[i - 1] = det_s
        det_sa = det_s
        rk = acf[:, :, i]
        cumtr += np.sum(np.diag(rk.T @ r0i @ rk @ r0i))
        q = n * cumtr + m * m * i * (i + 1) / 2 / n
        if i > npar:
            p_q[i - 1] = stats.chi2.sf(q, m * m * (i - npar))
    st["aic"] = aic
    st["sbc"] = sbc
    st["chi"] = chi
    st["p_chi"] = stats.chi2.sf(chi, m * m)
    st["p_q"] = p_q
    st["det_sigma"] = det_sigma
    return tsx_result("vident2", call={"ncoef": ncoef, "s": s, "npar": npar, "type": type},
                      series=names, acf=acf, se_acf=se_acf, pacf=pacf, se_pacf=se_pacf,
                      stats=st)


# --- Text and plots (print() and plot() methods of R)

@text_method("vident")
def tsx_text_vident(x, digits=None):
    d = 4 if digits is None else digits
    t = x["table"]
    lines = tsx_format_table(
        [t["lag"].to_numpy(), t["acf"].to_numpy(), tsx_signif_marks(t["acf"] / t["se_acf"]),
         t["q_lb"].to_numpy(), t["p_lb"].to_numpy(), t["pacf"].to_numpy(),
         tsx_signif_marks(t["pacf"] / t["se_pacf"]), t["q_mt"].to_numpy(), t["p_mt"].to_numpy()],
        [0, d, 0, d, d, d, 0, d, d],
        col_names=["Lag", "SACF", "", "LB", "P-value", "SPACF", "", "MT", "P-value"])
    return tsx_cat_block(title="Univariate Sample ACF and PACF",
                         notes=["LB: Ljung-Box Test", "MT: Monti (1994) Test",
                                "H0: Process is white noise", "Series " + x["series"]],
                         table=lines)


@plot_method("vident")
def tsx_plot_vident(x, fig):
    t = x["table"]
    tsx_plot_correlogram(
        fig, t["lag"].to_numpy(), t[["acf", "pacf"]].to_numpy(),
        t[["se_acf", "se_pacf"]].to_numpy(), x["call"]["s"],
        ["Series %s: Univariate Sample Autocorrelation Function" % x["series"],
         "Series %s: Univariate Sample Partial Autocorrelation Function" % x["series"]])


@text_method("vident2")
def tsx_text_vident2(x, digits=None):
    m = len(x["series"])
    if digits is None:
        digits = max(2, 7 - m)
    lab = "Partial Autoregression" if x["call"]["type"] == 1 else "Partial Lag Autocorrelation"
    out = ["-" * 60, "Multivariate Sample Autocorrelation and %s Functions" % lab, "-" * 60]

    def fmt(v):
        return " ".join(tsx_fmt_f(e, digits).rjust(digits + 4) for e in v)

    st = x["stats"]
    for k in range(x["call"]["ncoef"] + 1):
        if k > 0:
            s = st.iloc[k - 1]
            out.append(tsx_sprintf_f(
                "k=%d AIC=%.4f SBC=%.4f Chi=%.4f P-Chi=%.4f P-QTest=%.4f |Sigma|=%.4g",
                k, s["aic"], s["sbc"], s["chi"], s["p_chi"], s["p_q"], s["det_sigma"]))
        else:
            out.append("k= 0")
        a = x["acf"][:, :, k]
        p = x["pacf"][:, :, k]
        ma = tsx_signif_marks(a / x["se_acf"][:, :, k])
        if k == 0:
            mp = np.full((m, m), ".")
        else:
            rp = p / x["se_pacf"][:, :, k]
            rp[np.isnan(rp)] = 0
            mp = tsx_signif_marks(rp)
        for i in range(m):
            line = "".join(ma[i]) + " | " + "".join(mp[i]) + " | " + fmt(a[i, :])
            if k > 0:
                line += " | " + fmt(p[i, :])
            out.append(line)
        out.append("")
    return out


@plot_method("vident2")
def tsx_plot_vident2(x, fig, series=1):
    names = list(x["series"])
    m = len(names)
    sel = [series] if isinstance(series, (int, str, np.integer)) else list(series)
    idx = []
    for s in sel:
        if isinstance(s, str):
            idx.append(names.index(s) + 1 if s in names else -1)
        else:
            idx.append(int(s))
    if any(i < 1 or i > m for i in idx):
        raise ValueError("Invalid 'series'.")
    i = idx[0] - 1
    j = idx[1] - 1 if len(idx) > 1 else i
    nc = x["call"]["ncoef"]
    lab = "Partial Autoregression" if x["call"]["type"] == 1 else "Partial Lag Autocorrelation"
    if i == j:
        lags = np.arange(1, nc + 1)
        v = np.column_stack([x["acf"][i, i, 1:], x["pacf"][i, i, 1:]])
        se = np.column_stack([x["se_acf"][i, i, 1:], x["se_pacf"][i, i, 1:]])
        titles = ["Series %s: Multivariate Sample Autocorrelation Function" % names[i],
                  "Series %s: Multivariate Sample %s Function" % (names[i], lab)]
    else:
        lags = np.arange(-nc, nc + 1)

        def side(arr):
            return np.r_[arr[i, j, 1:][::-1], arr[i, j, 0], arr[j, i, 1:]]

        v = np.column_stack([side(x["acf"]), side(x["pacf"])])
        se = np.column_stack([side(x["se_acf"]), side(x["se_pacf"])])
        ni, nj = names[i], names[j]
        tail = "between %s(t) and %s(t-k) [k < 0] and %s(t-k) and %s(t) [k > 0]" % (ni, nj, ni,
                                                                                    nj)
        titles = ["CCF " + tail, "PCCF " + tail]
    tsx_plot_correlogram(fig, lags, v, se, x["call"]["s"], titles)
