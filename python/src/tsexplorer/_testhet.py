import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import text_method, tsx_result
from ._utils_input import as_tsx_matrix
from ._utils_math import nanvar
from ._utils_print import tsx_cat_block, tsx_format_table, tsx_num2str


def testhet(y, timecuts=None, names=None):
    """Heteroskedasticity tests.

    Variance ratio F tests between non-overlapping subsamples of each
    series.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    timecuts : list or 2-D array, optional
        Definition of the subsamples (observation numbers, from 1):

        * a vector of ``n`` cut points divides the sample into ``n + 1``
          consecutive subsamples (cut points closer than 5 observations to
          the ends are discarded),
        * a ``n x 2`` matrix gives the first and last observation of each
          subsample (overlapping or invalid rows are discarded).

        If no valid subsamples remain, the sample is split into three parts.
        Default ``[floor(T / 3), floor(2 * T / 3) + 2]``.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_testhet`` with fields ``call``, ``series``,
        ``samples`` (matrix with first and last observation of each
        subsample) and ``table``, a DataFrame with columns ``series``,
        ``start1``, ``end1``, ``start2``, ``end2``, ``f`` (ratio of
        variances, always <= 1) and ``p_value`` (two sided).

    See Also
    --------
    TsxResult.text, vcusum, stdmean

    Examples
    --------
    >>> airpas = load_data("airpas")
    >>> testhet(airpas)
    >>> testhet(np.log(airpas), [48, 96])
    >>> testhet(airpas, [[1, 30], [50, 90], [100, 144]])
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    cuts = tsx_timecuts(timecuts, n)
    rows = []
    for s in range(y.shape[1]):
        for i in range(cuts.shape[0] - 1):
            for j in range(i + 1, cuts.shape[0]):
                zi = y[int(cuts[i, 0]) - 1:int(cuts[i, 1]), s]
                zj = y[int(cuts[j, 0]) - 1:int(cuts[j, 1]), s]
                f = nanvar(zi) / nanvar(zj)
                d1 = np.sum(~np.isnan(zi)) - 1
                d2 = np.sum(~np.isnan(zj)) - 1
                if f > 1:
                    f = 1 / f
                    d1, d2 = d2, d1
                rows.append({"series": names[s], "start1": cuts[i, 0], "end1": cuts[i, 1],
                             "start2": cuts[j, 0], "end2": cuts[j, 1], "f": f,
                             "p_value": 2 * stats.f.cdf(f, d1, d2)})
    return tsx_result("testhet", call={"timecuts": timecuts}, series=names, samples=cuts,
                      table=pd.DataFrame(rows))


def tsx_timecuts(timecuts, n):
    """Subsamples of testhet (first and last observation in each row)."""
    def default():
        i1 = math.floor(n / 3)
        i2 = math.floor(2 * n / 3) + 2
        return np.array([[1, i1], [i1 + 1, i2], [i2 + 1, n]], dtype=float)

    if timecuts is None or np.size(timecuts) == 0:
        timecuts = [math.floor(n / 3), math.floor(2 * n / 3) + 2]
    tc = np.asarray(timecuts, dtype=float)
    if tc.ndim < 2 or 1 in tc.shape:
        tc = np.sort(tc.ravel(order="F"))
        tc = tc[~((tc < 5) | (tc > n - 5))]
        if len(tc) == 0:
            return default()
        cuts = np.column_stack([np.r_[1, tc + 1], np.r_[tc, n]])
    else:
        cuts = np.sort(tc, axis=1)
        cuts = cuts[np.argsort(cuts[:, 0], kind="stable"), :]
        drop = list(np.nonzero(cuts[1:, 0] < 5)[0] + 1) + list(np.nonzero(cuts[:, 0] > n - 5)[0])
        if drop:
            cuts = np.delete(cuts, sorted(set(drop)), axis=0)
        drop = np.nonzero(np.diff(cuts[:, 1]) < 0)[0] + 1
        if len(drop):
            cuts = np.delete(cuts, drop, axis=0)
        drop = np.nonzero((cuts[1:, 0] - cuts[:-1, 1]) < 0)[0] + 1
        if len(drop):
            cuts = np.delete(cuts, drop, axis=0)
    if cuts.shape[0] < 2:
        return default()
    return cuts.astype(float)


# --- Text output (print() method of R)

@text_method("testhet")
def tsx_text_testhet(x, digits=None):
    digits = 4 if digits is None else digits
    out = ["-" * 50, "Variance Ratio Tests", "-" * 50,
           "H0: Variances are the same (homoskedasticity).",
           "(Assumptions: Independence and Normality)"]
    tab = x["table"]
    for s in x["series"]:
        t = tab[tab["series"] == s]
        rn = ["Samples (%s - %s) / (%s - %s):" % tuple(tsx_num2str(v) for v in r)
              for r in t[["start1", "end1", "start2", "end2"]].to_numpy()]
        out += [""] + tsx_cat_block(title="Series %s:" % s,
                                    table=tsx_format_table(t[["f", "p_value"]], digits,
                                                           row_names=rn,
                                                           col_names=["F-Test", "P-value"]))
    return out
