import math
import re

import numpy as np
import pandas as pd
from scipy import stats

from ._result import text_method, tsx_result
from ._utils_input import as_tsx_matrix
from ._utils_math import nanmean, tsx_mvar
from ._utils_print import tsx_cat_block, tsx_format_table


def vgranger(y, lags=None, tests=None, names=None):
    """Granger causality tests.

    Wald tests (F and chi-squared versions) of Granger non-causality on a
    VAR model without constant estimated on the demeaned series.

    Each test is written with letters for the series (``a`` is the first
    one, ``b`` the second, ...): the letters before ``-`` are the equations
    and the letters after ``-`` the possibly causing variables. For instance
    ``"a-b"`` tests whether ``b`` causes ``a``, and ``"ab-c"`` whether ``c``
    causes ``a`` and ``b``.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`), at least two series.
    lags : int or list of int, optional
        Lags of the VAR model (block constraints are possible, e.g. ``[1, 2,
        12]``). Default ``1..min(floor(sqrt(T)), 20)``. If the largest lag
        exceeds ``T / 2``, ``[1, 2]`` is used.
    tests : str or list of str, optional
        Tests (or a single blank-separated string). Default: every pair of
        series in both directions. Invalid tests are ignored.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vgranger`` with fields ``call``, ``series``
        and ``table``, a DataFrame with columns ``test``, ``h0``,
        ``constraints``, ``f``, ``p_f``, ``chi2``, ``p_chi2``.

    See Also
    --------
    TsxResult.text, varsbc, vident2

    References
    ----------
    Granger, C.W.J. (1969). Investigating causal relations by econometric
    models and cross-spectral methods. *Econometrica*, 37, 424-438.

    Examples
    --------
    >>> vgranger(vdif(np.log(load_data("lydia_pinkham"))), lags=[1, 2, 3])
    """
    y, names, _ = as_tsx_matrix(y, names)
    n, m = y.shape
    if m < 2:
        raise ValueError("'vgranger' needs at least two series.")
    if lags is None or np.size(lags) == 0:
        lags = list(range(1, min(math.floor(math.sqrt(n)), 20) + 1))
    lags = [int(round(v)) for v in np.atleast_1d(lags)]
    if max(lags) > n / 2:
        lags = [1, 2]
    nlags = len(lags)
    tests = tsx_granger_tests(tests, m)
    z = y - nanmean(y, axis=0)
    v = tsx_mvar(z, lags, const=False)
    beta = (-v["p"]).T.ravel(order="F")
    vbeta = np.kron(v["inv_xx"], v["sigma"])
    npar = m * m * nlags
    rows = []
    for test in tests:
        left, right = test.split("-")
        eqs = [ord(c) - 96 for c in left]
        causes = [ord(c) - 96 for c in right]
        nconst = len(causes) * len(eqs) * nlags
        cm = np.zeros((nconst, npar))
        r = 0
        for ci in causes:
            for ei in eqs:
                for lag in range(1, nlags + 1):
                    cm[r, (ci - 1) * m + ei + (lag - 1) * m * m - 1] = 1
                    r += 1
        cb = cm @ beta
        w = float(cb @ np.linalg.solve(cm @ vbeta @ cm.T, cb))
        df2 = n * m - npar + m * m
        rows.append({
            "test": test,
            "h0": "%s %s not cause %s" % (tsx_and_list([names[c - 1] for c in causes]),
                                          "do" if len(causes) > 1 else "does",
                                          tsx_and_list([names[e - 1] for e in eqs])),
            "constraints": nconst, "f": w / nconst,
            "p_f": stats.f.sf(w / nconst, nconst, df2), "chi2": w,
            "p_chi2": stats.chi2.sf(w, nconst)})
    return tsx_result("vgranger", call={"lags": lags, "tests": tests}, series=names,
                      table=pd.DataFrame(rows))


def tsx_and_list(x):
    if len(x) == 1:
        return x[0]
    return ", ".join(x[:-1]) + " and " + x[-1]


def tsx_granger_tests(tests, m):
    """Default and validation of Granger tests."""
    letters = "abcdefghijklmnopqrstuvwxyz"
    default = ["%s-%s" % (letters[i], letters[j])
               for j in range(m) for i in range(m) if i != j]
    if tests is None or (not isinstance(tests, str) and len(tests) == 0):
        return default
    if isinstance(tests, str):
        tests = [tests]
    tests = list(tests)
    if len(tests) == 1:
        tests = re.split(r"\s+", tests[0].strip())
    tests = [re.sub(r"\s", "", t).lower() for t in tests]

    def ok(t):
        if not re.fullmatch(r"[a-z]+-[a-z]+", t):
            return False
        let = [ord(c) - 96 for c in t.replace("-", "")]
        return all(1 <= v <= m for v in let) and len(set(let)) == len(let)

    tests = [t for t in tests if ok(t)]
    return tests if tests else default


# --- Text output (print() method of R)

@text_method("vgranger")
def tsx_text_vgranger(x, digits=None):
    digits = 4 if digits is None else digits
    lags = x["call"]["lags"]
    const = "" if max(lags) == len(lags) else "CONSTRAINED "
    t = x["table"]
    return tsx_cat_block(
        title=["Granger Causality Tests", "Based on a %sVAR(%d) model" % (const, max(lags))],
        table=tsx_format_table(t[["constraints", "f", "p_f", "chi2", "p_chi2"]],
                               [0] + [digits] * 4, row_names=list(t["h0"]),
                               col_names=["Constraints", "F-Stat", "P-value", "Chi-stat",
                                          "P-value"]))
