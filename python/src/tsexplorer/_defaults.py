import copy
import math

import numpy as np

from ._utils_input import as_tsx_matrix
from ._utils_math import tsx_seq_by
from ._vgranger import tsx_granger_tests

# Groups of linked options (tool, option).
TOOLTEST_LINKS = {
    "s": [("plotband", "s"), ("vboxplot", "s"), ("vtboxplot", "s"), ("vident", "s"),
          ("vident2", "s"), ("stdmean", "s"), ("vboxcox", "group")],
    "ncoef_acf": [("vident", "ncoef"), ("vident2", "ncoef"), ("varsbc", "ncoef")],
    "lags_unitroot": [("adftest", "lags"), ("vphillips", "lags"), ("johansentest", "lags")],
    "ncoef_nl": [("nltests", "ncoef"), ("varsbc2", "ncoef")],
}


class ToolDefaults(dict):
    """Options of every tool (dict of dicts) with the groups of linked
    options in the attribute ``links`` (attribute ``"links"`` in R)."""

    links = TOOLTEST_LINKS


def _same(a, b):
    if a is None or b is None:
        return a is None and b is None
    try:
        return bool(np.array_equal(np.asarray(a, dtype=object), np.asarray(b, dtype=object)))
    except Exception:
        return a == b


def tooltest_defaults(y, **overrides):
    """Default options of the tools of tooltest().

    Single source of the default options of every tool (they depend on the
    sample size ``T`` and the number of series ``m``). It is used by the
    :func:`tooltest` application; the functions of the package resolve the
    same defaults when their arguments are ``None``.

    Some options are linked across tools: the seasonal period ``s``
    (``plotband``, ``vboxplot``, ``vtboxplot``, ``vident``, ``vident2``,
    ``stdmean`` and the ``group`` of ``vboxcox``), the number of lags of the
    correlograms (``vident``, ``vident2``, ``varsbc``), the lags of the unit
    root tests (``adftest``, ``vphillips``, ``johansentest``) and the number
    of lags of the non-linearity tests (``nltests``, ``varsbc2``). The groups
    are in the attribute ``links`` of the result.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    **overrides
        Options to override, given per tool as a dict, e.g.
        ``vident={"ncoef": 50, "s": 4, "npar": 1}``. A list or tuple assigns
        its elements in the order of the options of the tool, e.g.
        ``varspectrum=[16]``; any other value is the first option of the
        tool. When a linked option is changed in one tool, it is propagated
        to the other tools of its group.

    Returns
    -------
    ToolDefaults
        A dict (one element per tool) of dicts of options, with attribute
        ``links``.

    See Also
    --------
    tooltest

    Examples
    --------
    >>> tooltest_defaults(load_data("airpas"))["vident"]
    >>> tooltest_defaults(load_data("airpas"), vboxplot={"s": 4})["plotband"]["s"]
    """
    y, _, _ = as_tsx_matrix(y)
    n, m = y.shape
    lmax = min(math.floor(math.sqrt(n)), 20)
    ur_lags = list(range(1, lmax + 1)) if m == 1 else [lmax]
    nc_acf = min(38, math.ceil(n / 4 / m * 2))
    nc_nl = min(38, math.ceil(math.sqrt(n)))
    xlog = [False, True]
    default = {
        "plotband": {"s": 12, "standard": False, "fixed": True},
        "vboxplot": {"s": 12},
        "vtboxplot": {"s": 12},
        "vscatter": {"bins": math.ceil(math.sqrt(n))},
        "sumstats": {"digits": 4, "gaussian": True, "nsimul": 3000},
        "vhist": {"bins": math.ceil(math.sqrt(n))},
        "vqqplot": {},
        "gausstest": {"digits": 4},
        "vident": {"ncoef": nc_acf, "s": 12, "npar": 0},
        "vident2": {"ncoef": nc_acf, "s": 12, "npar": 0, "type": 0},
        "varsbc": {"ncoef": nc_acf},
        "vgranger": {"lags": list(range(1, lmax + 1)),
                     "tests": tsx_granger_tests(None, m) if m > 1 else None},
        "vcusum": {},
        "stdmean": {"s": 12, "type": 0, "numbers": True},
        "testhet": {"timecuts": [math.floor(n / 3), math.floor(2 * n / 3) + 2]},
        "vboxcox": {"group": 12, "axislambdas": [float(v) for v in tsx_seq_by(-1, 1, 0.1)]},
        "adftest": {"lags": ur_lags},
        "vphillips": {"lags": list(ur_lags), "ncovs": math.floor(4 * (n / 100) ** 0.25)},
        "johansentest": {"lags": list(ur_lags)},
        "nltests": {"ncoef": nc_nl},
        "vtsay": {"lags": 4},
        "varsbc2": {"ncoef": nc_nl},
        "vbds": {"maxdim": 2, "distance": 1.5},
        "vcumperiod": {},
        "vspectrum": {"smooth": 1, "xlog": list(xlog)},
        "varspectrum": {"order": 16, "nfreq": n // 2, "xlog": list(xlog)},
    }
    if overrides:
        out = copy.deepcopy(default)
        for tool, val in overrides.items():
            if tool not in default:
                raise ValueError("Unknown tool: " + tool)
            onames = list(default[tool])
            if isinstance(val, dict):
                items = list(val.items())
            else:
                vals = list(val) if isinstance(val, (list, tuple)) else [val]
                items = [(None, v) for v in vals]
            for k, (key, v) in enumerate(items):
                if key is None:
                    if k >= len(onames):
                        raise ValueError("Unknown option for %s: %d" % (tool, k + 1))
                    key = onames[k]
                elif key not in onames:
                    raise ValueError("Unknown option for %s: %s" % (tool, key))
                if v is not None:
                    out[tool][key] = v
        # Propagate linked options (the last changed member of each group
        # wins, in a fixed order).
        for group in TOOLTEST_LINKS.values():
            changed = None
            for tool, key in group:
                if not _same(out[tool][key], default[tool][key]):
                    changed = out[tool][key]
            if changed is not None:
                for tool, key in group:
                    out[tool][key] = copy.deepcopy(changed)
        default = out
    return ToolDefaults(default)
