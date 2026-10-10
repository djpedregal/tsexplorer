import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import text_method, tsx_result
from ._utils_input import as_tsx_matrix
from ._utils_math import (meda, nanmean, nansd, tsx_hist, tsx_interpol, tsx_kurtosis,
                          tsx_ksdensity, tsx_mean, tsx_mode, tsx_nancorr, tsx_prctile, tsx_signif_marks,
                          tsx_skewness)
from ._utils_print import tsx_fmt_f, tsx_format_table


def sumstats(y, gaussian=True, nsimul=3000, digits=4, seed=None, names=None):
    """Summary descriptive statistics.

    Computes for every series the number of data points, missing values,
    percentiles, means (arithmetic, geometric and harmonic), dispersion
    measures, skewness and kurtosis, a test of zero mean and, for more than
    one series, the correlation matrix.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    gaussian : bool
        If ``True`` (default) the probability of zero mean is computed from
        the t distribution; if ``False`` it is estimated by bootstrap
        (``nsimul`` replications) smoothed with a kernel density.
    nsimul : int
        Number of bootstrap replications when ``gaussian=False``.
    digits : int
        Number of decimals for printing.
    seed : int, optional
        Seed of the random number generator of the bootstrap (a new
        ``numpy.random.Generator`` is used; the global state is not
        changed).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_sumstats`` with fields

        * ``call``: options used,
        * ``series``: names of the series,
        * ``stats``: DataFrame with one row per series and columns
          ``series``, ``n``, ``missing``, ``min``, ``p10``, ``p25``,
          ``mean``, ``p_mean_zero``, ``geometric_mean``, ``harmonic_mean``,
          ``median``, ``mode``, ``p75``, ``p90``, ``max``, ``iqr``, ``range``,
          ``sd``, ``var``, ``mean_abs_dev``, ``median_abs_dev``,
          ``mean_sd_ratio``, ``skewness``, ``kurtosis`` (excess kurtosis).
          ``p_mean_zero`` is the two sided p-value of the test of zero mean
          and ``range`` is ``max - min``. ``mode`` is the most frequent value
          (the smallest one in case of ties; with continuous data with no
          repeated values it equals the minimum),
        * ``cor``: correlation matrix (``None`` for one series) and
          ``se_cor`` its standard error :math:`1/\\sqrt{T}`.

    See Also
    --------
    TsxResult.text, gausstest

    Examples
    --------
    >>> sumstats(load_data("airpas"))
    >>> sumstats(load_data("scc"), names=["A", "B", "C"])
    """
    y, names, _ = as_tsx_matrix(y, names)
    n_obs, m = y.shape

    def pick(f):
        out = np.full(m, np.nan)
        for i in range(m):
            x = y[~np.isnan(y[:, i]), i]
            if len(x) > 0:
                out[i] = f(x)
        return out

    def harmonic(x):
        x = x[np.abs(x) > 1e-5]
        with np.errstate(all="ignore"):
            return 1 / (np.sum(1 / x) / len(x)) if len(x) > 0 else np.nan

    st = pd.DataFrame({"series": names})
    st["n"] = n_obs
    st["missing"] = np.sum(np.isnan(y), axis=0)
    st["min"] = pick(np.min)
    st["p10"] = pick(lambda x: tsx_prctile(x, 10)[0, 0])
    st["p25"] = pick(lambda x: tsx_prctile(x, 25)[0, 0])
    st["mean"] = pick(tsx_mean)
    st["p_mean_zero"] = np.nan
    st["geometric_mean"] = pick(lambda x: np.exp(tsx_mean(np.log(x))) if np.all(x > 0) else np.nan)
    st["harmonic_mean"] = pick(harmonic)
    st["median"] = pick(np.median)
    st["mode"] = pick(tsx_mode)
    st["p75"] = pick(lambda x: tsx_prctile(x, 75)[0, 0])
    st["p90"] = pick(lambda x: tsx_prctile(x, 90)[0, 0])
    st["max"] = pick(np.max)
    st["iqr"] = st["p75"] - st["p25"]
    st["range"] = st["max"] - st["min"]
    st["sd"] = pick(lambda x: np.std(x, ddof=1) if len(x) > 1 else np.nan)
    st["var"] = st["sd"] ** 2
    st["mean_abs_dev"] = pick(lambda x: tsx_mean(np.abs(x - tsx_mean(x))))
    st["median_abs_dev"] = meda(y)
    st["mean_sd_ratio"] = st["mean"] / st["sd"]
    st["skewness"] = pick(tsx_skewness)
    st["kurtosis"] = pick(tsx_kurtosis) - 3
    nn = (st["n"] - st["missing"]).to_numpy(dtype=float)
    tstat = (st["mean"] / (st["sd"] / np.sqrt(nn))).to_numpy()
    if gaussian:
        st["p_mean_zero"] = 2 * stats.t.sf(np.abs(tstat), nn - 1)
    else:
        st["p_mean_zero"] = tsx_auxsumstats(y, tstat, nsimul, np.random.default_rng(seed))
    cor = tsx_nancorr(y) if m > 1 else None
    return tsx_result("sumstats",
                      call={"gaussian": gaussian, "nsimul": nsimul, "digits": digits,
                            "seed": seed},
                      series=names, stats=st, cor=cor, se_cor=1 / math.sqrt(n_obs))


def tsx_auxsumstats(y, tstats, nsimul, rng):
    """Bootstrap probability of zero mean (two sided: twice the bootstrap
    probability of a statistic of the opposite sign)."""
    n, m = y.shape
    bins = math.ceil(math.sqrt(n))
    simul = np.full((nsimul, m), np.nan)
    for i in range(nsimul):
        zi = y[rng.integers(0, n, n), :]
        simul[i, :] = nanmean(zi, axis=0) / (nansd(zi, axis=0) / math.sqrt(n))
    out = np.full(m, np.nan)
    for i in range(m):
        zi = simul[:, i]
        zi = zi[np.isfinite(zi)]
        centers = tsx_hist(zi, bins)["mids"]
        lim = (math.floor(np.min(centers)), math.ceil(np.max(centers)))
        xaxis = np.linspace(lim[0], lim[1], 181)
        fi = np.cumsum(tsx_ksdensity(zi, xaxis))
        fi = fi / np.max(fi)
        r = tsx_interpol(xaxis, fi, 0)
        if tstats[i] < 0:
            r = 1 - r
        out[i] = min(1, max(0, 2 * r))
    return out


# --- Text output (print() method of R)

@text_method("sumstats")
def tsx_text_sumstats(x, digits=None):
    if digits is None:
        digits = x["call"]["digits"]
    st = x["stats"]
    lab = ["Data points:", "Missing:", "Minimum:", "10% percentile:", "25% percentile:", "Mean:",
           "P(Mean= 0, Gaussian):" if x["call"]["gaussian"] else "P(Mean= 0, Empirical):",
           "Geometric Mean:", "Harmonic Mean:", "Median:", "Mode:", "75% percentile:",
           "90% percentile:", "Maximum:", "Interquartile Range:", "Range:",
           "Standard Deviation:", "Variance:", "Mean Absolute Deviation:",
           "Median Absolute Deviation:", "Mean/Standard Deviation:", "Skewness:",
           "Kurtosis (-3):"]
    vals = st.iloc[:, 1:].to_numpy(dtype=float).T
    series = list(x["series"])
    tab = [[tsx_fmt_f(vals[i, j], 0 if i < 2 else digits) for j in range(vals.shape[1])]
           for i in range(vals.shape[0])]
    w = max(len(s) for s in [c for r in tab for c in r] + series)
    lw = max(len(s) for s in lab)
    head = " " * lw + " " + "  ".join(s.rjust(w) for s in series)
    body = [lab[i].ljust(lw) + " " + "  ".join(c.rjust(w) for c in tab[i])
            for i in range(len(lab))]
    rule = "-" * max(len(s) for s in [head] + body)
    out = ([rule, head, rule] + body[0:2] + [rule] + body[2:14] + [rule] + body[14:21]
           + [rule] + body[21:23] + [rule])
    if x["cor"] is not None:
        cm = x["cor"]
        marks = tsx_signif_marks(cm / x["se_cor"])
        tabc = tsx_format_table(cm, digits, row_names=series, col_names=series)
        mk = [""] + ["".join(r) for r in marks]
        out += ["", "Correlation Matrix:"]
        out += [tabc[i] + "  |  " + mk[i] for i in range(len(tabc))]
    return out
