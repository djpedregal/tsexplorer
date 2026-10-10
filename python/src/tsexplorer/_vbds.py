import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int
from ._utils_math import nanmax, nanmean, nansd
from ._utils_print import tsx_cat_block, tsx_format_g, tsx_format_table


def vbds(y, maxdim=2, distance=1.5, names=None):
    """BDS test of independence.

    Brock, Dechert and Scheinkman (BDS) test of the null hypothesis that a
    series is independent and identically distributed, for embedding
    dimensions ``2..maxdim``. P-values are asymptotic (standard normal).

    The computations follow the implementation of Ludwig Kanzler (1998),
    rewritten without the bitwise storage that program uses to save memory.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    maxdim : int
        Maximum embedding dimension (at least 2). Default 2.
    distance : float
        Dimensional distance as a fraction of the standard deviation of each
        series. Default 1.5. It is reduced to ``min(0.9 * (max(y) - mean(y))
        / sd(y))`` (minimum over the series) if larger than that.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vbds`` with fields ``call`` (effective
        ``maxdim`` and ``distance``), ``series`` and ``table``, a DataFrame
        with columns ``series``, ``dim``, ``w`` (BDS statistic) and
        ``p_value``.

    See Also
    --------
    TsxResult.text, nltests, vtsay

    References
    ----------
    Brock, W.A., Dechert, W.D., Scheinkman, J.A. and LeBaron, B. (1996). A
    test for independence based on the correlation dimension. *Econometric
    Reviews*, 15, 197-235.

    Kanzler, L. (1999). Very fast and correctly sized estimation of the BDS
    statistic. Working paper, University of Oxford.

    Examples
    --------
    >>> vbds(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]), maxdim=4)
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    maxdim = min(tsx_check_int(maxdim, "maxdim", 2), n // 2)
    # The limit is expressed, as 'distance', in standard deviations
    lim = 0.9 * (nanmax(y, axis=0) - nanmean(y, axis=0)) / nansd(y, axis=0)
    distance = float(min(distance, np.min(lim)))
    tabs = []
    for i in range(y.shape[1]):
        x = y[~np.isnan(y[:, i]), i]
        b = tsx_bds(x, maxdim, distance)
        tabs.append(pd.DataFrame({"series": names[i], "dim": np.arange(2, maxdim + 1),
                                  "w": b["w"], "p_value": b["p_value"]}))
    return tsx_result("vbds", call={"maxdim": maxdim, "distance": distance}, series=names,
                      table=pd.concat(tabs, ignore_index=True))


def tsx_bds(x, maxdim, distance):
    """BDS statistic (Kanzler 1998) with epsilon = distance * sd(x).
    Closeness indicators are processed one lag (diagonal) at a time."""
    x = np.asarray(x, dtype=float)
    n = len(x)
    eps = distance * np.std(x, ddof=1)
    fullsum = np.ones(n)            # 1 + number of neighbours of each point
    pairs_from = np.zeros(maxdim)   # close pairs (i, j), i < j, with i >= m
    cm = np.zeros(maxdim)           # close m-histories
    for d in range(1, n):
        b = np.abs(x[:n - d] - x[d:]) <= eps
        fullsum[:n - d] += b
        fullsum[d:] += b
        for m in range(1, maxdim + 1):
            if m <= n - d:
                pairs_from[m - 1] += np.sum(b[m - 1:n - d])
        # a[t] = 1 if the m-histories ending at t and t + d are close:
        # a_m[t] = a_(m-1)[t] & b[t - m + 1], for t = m, ..., n - d
        length = n - d
        a = b
        for m in range(2, maxdim + 1):
            if m > length:
                break
            a_new = np.zeros(length, dtype=bool)
            a_new[m - 1:] = a[m - 1:] & b[:length - m + 1]
            a = a_new
            cm[m - 1] += np.sum(a[m - 1:])

    def npairs(k):
        return k * (k + 1) / 2

    c1 = np.array([pairs_from[m - 1] / npairs(n - m) for m in range(1, maxdim + 1)])
    bitsum1 = pairs_from[0]
    k = (np.sum(fullsum ** 2) + 2 * n - 3 * (2 * bitsum1 + n)) / n / (n - 1) / (n - 2)
    w = np.zeros(maxdim - 1)
    for m in range(2, maxdim + 1):
        cmm = cm[m - 1] / npairs(n - m)
        j = np.arange(1, m)
        sigma = 2 * math.sqrt(k ** m + 2 * np.sum(k ** (m - j) * c1[0] ** (2 * j))
                              + (m - 1) ** 2 * c1[0] ** (2 * m)
                              - m ** 2 * k * c1[0] ** (2 * m - 2))
        w[m - 2] = math.sqrt(n - m + 1) * (cmm - c1[m - 1] ** m) / sigma
    p = 2 * np.minimum(stats.norm.cdf(w), 1 - stats.norm.cdf(w))
    return {"w": w, "p_value": p, "c1": c1, "k": k}


# --- Text output (print() method of R)

@text_method("vbds")
def tsx_text_vbds(x, digits=None):
    d = 4 if digits is None else digits
    multi = len(x["series"]) > 1
    t = x["table"]
    return tsx_cat_block(
        title="Brock, Dechert & Scheinkman (BDS) Test",
        notes=["H0: Process is linear and i.i.d.",
               "Distance as a fraction of the S.D.: " + tsx_format_g(x["call"]["distance"])],
        table=tsx_format_table(t[["dim", "w", "p_value"]], [0, d, d],
                               row_names=list(t["series"]) if multi else None,
                               col_names=["Dim", "BDS", "P-value"]))
