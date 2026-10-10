import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import text_method, tsx_result
from ._tables import tsx_tables
from ._utils_input import as_tsx_matrix
from ._utils_math import tsx_interpol, tsx_kurtosis, tsx_skewness
from ._utils_print import tsx_cat_block, tsx_format_table


def gausstest(y, digits=4, names=None):
    """Gaussianity tests.

    Bera-Jarque and Kolmogorov-Smirnov-Lilliefors tests of normality for
    every series and, for more than one series, the multivariate Bera-Jarque
    test.

    The Lilliefors p-values are approximate: they are interpolated (and
    linearly extrapolated, clamped to ``[0, 1]``) in the table of critical
    values of Lilliefors (1967) for p = 0.20, 0.15, 0.10, 0.05 and 0.01.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    digits : int
        Number of decimals for printing.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_gausstest`` with fields ``call``, ``series``,
        ``table`` (DataFrame with columns ``series``, ``n``, ``skewness``,
        ``kurtosis`` (excess), ``bj``, ``p_bj``, ``ksl``, ``p_ksl``) and, for
        more than one series, ``bj_multi`` and ``p_bj_multi`` (``None``
        otherwise).

    See Also
    --------
    TsxResult.text, vhist, vqqplot

    References
    ----------
    Jarque, C.M. and Bera, A.K. (1987). A test for normality of observations
    and regression residuals. *International Statistical Review*, 55,
    163-172.

    Lilliefors, H.W. (1967). On the Kolmogorov-Smirnov test for normality
    with mean and variance unknown. *Journal of the American Statistical
    Association*, 62, 399-402.

    Examples
    --------
    >>> gausstest(load_data("airpas"))
    >>> gausstest(np.log(load_data("airpas")))
    """
    y, names, _ = as_tsx_matrix(y, names)
    m = y.shape[1]
    skew = np.zeros(m)
    kurt = np.zeros(m)
    n = np.zeros(m, dtype=int)
    d = np.zeros(m)
    pd_ = np.zeros(m)
    for i in range(m):
        zi = y[~np.isnan(y[:, i]), i]
        n[i] = len(zi)
        skew[i] = tsx_skewness(zi)
        kurt[i] = tsx_kurtosis(zi) - 3
        d[i] = tsx_lilliefors_stat(zi)
        pd_[i] = tsx_lilliefors_p(d[i], n[i])
    bj = n / 6 * (skew ** 2 + kurt ** 2 / 4)
    tab = pd.DataFrame({"series": names, "n": n, "skewness": skew, "kurtosis": kurt,
                        "bj": bj, "p_bj": stats.chi2.sf(bj, 2), "ksl": d, "p_ksl": pd_})
    bj_multi = p_bj_multi = None
    if m > 1:
        bj_multi = float(np.sum(bj))
        p_bj_multi = float(stats.chi2.sf(bj_multi, 2 * m))
    return tsx_result("gausstest", call={"digits": digits}, series=names, table=tab,
                      bj_multi=bj_multi, p_bj_multi=p_bj_multi)


def tsx_lilliefors_stat(x):
    """Kolmogorov-Smirnov statistic against a normal with estimated mean and
    standard deviation: max(D+, D-)."""
    x = np.sort(x)
    n = len(x)
    f = stats.norm.cdf(x, np.mean(x), np.std(x, ddof=1))
    i = np.arange(1, n + 1)
    return max(np.max(i / n - f), np.max(f - (i - 1) / n))


def tsx_lilliefors_p(d, n):
    """Approximate p-value of the Lilliefors test (interpolated in a table
    of critical values)."""
    tb = tsx_tables()
    if n > 30:
        crit = np.array([0.736, 0.768, 0.805, 0.886, 1.031]) / math.sqrt(n)
    elif n < 5:
        return np.nan
    else:
        crit = tb["lillie"][n - 5, :]
    return tsx_interpol(crit, tb["lillie_p"], d, (0, 1))


# --- Text output (print() method of R)

@text_method("gausstest")
def tsx_text_gausstest(x, digits=None):
    if digits is None:
        digits = x["call"]["digits"]
    tab = x["table"][["skewness", "kurtosis", "bj", "p_bj", "ksl", "p_ksl"]]
    lines = tsx_format_table(tab, digits, row_names=x["series"],
                             col_names=["Skewness", "Kurtosis(-3)", "Bera-Jarque", "P-value",
                                        "KSLilliefors", "P-value"])
    out = tsx_cat_block(
        title="Bera-Jarque and Kolmogorov-Smirnov Lilliefors (KSL) gaussianity tests.",
        notes=["H0: Distribution is gaussian.", "(Assumptions: Independence)",
               "(Approximate P-value for KSL test)."],
        table=lines)
    if x["bj_multi"] is not None:
        out += [""] + tsx_cat_block(table=tsx_format_table(
            [np.array([x["bj_multi"]]), np.array([x["p_bj_multi"]])], digits,
            col_names=["Multivariate Bera-Jarque", "P-value"]))
    return out
