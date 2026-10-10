# Tables of critical values (R/sysdata.rda in the R version), read once from
# the CSV files in data/tables (copies of r/inst/extdata/tables).

import functools
import os

import numpy as np
import pandas as pd

_DIR = os.path.join(os.path.dirname(__file__), "data", "tables")


def _unique(x):
    return list(dict.fromkeys(x))


@functools.lru_cache(maxsize=None)
def tsx_tables():
    """Critical value tables: dict with ``adf_sizes``, ``adf_p_t``,
    ``adf_p_f``, ``adf`` (one matrix sizes x probabilities per table),
    ``adf_tri`` (triangles, 0-based indices of the points), ``joh_p``, ``joh``
    (matrices g x probabilities), ``lillie_n``, ``lillie_p`` and ``lillie``
    (matrix n x probabilities)."""
    t = {}
    adf = pd.read_csv(os.path.join(_DIR, "adf_critical.csv"))
    t["adf_sizes"] = np.array(_unique(adf["size"]), dtype=float)
    t["adf"] = {}
    for name in _unique(adf["table"]):
        rows = adf[adf["table"] == name]
        p = np.array(_unique(rows["p"]), dtype=float)
        t["adf_p_t" if name.startswith("t") else "adf_p_f"] = p
        # rows = sample sizes, columns = probabilities
        t["adf"][name] = rows["value"].to_numpy(dtype=float).reshape(
            (len(t["adf_sizes"]), len(p)), order="F")
    tri = pd.read_csv(os.path.join(_DIR, "adf_triangulation.csv"))
    t["adf_tri"] = {}
    for name in t["adf"]:
        rows = tri[tri["table"] == name]
        t["adf_tri"][name] = rows[["v1", "v2", "v3"]].to_numpy(dtype=int) - 1
    joh = pd.read_csv(os.path.join(_DIR, "johansen_critical.csv"))
    t["joh_p"] = np.array(_unique(joh["p"]), dtype=float)
    t["joh"] = {}
    for name in _unique(joh["table"]):
        v = joh.loc[joh["table"] == name, "value"].to_numpy(dtype=float)
        # rows = number of non-stationary directions g, columns = p-values
        t["joh"][name] = v.reshape((-1, len(t["joh_p"])), order="F")
    lil = pd.read_csv(os.path.join(_DIR, "lilliefors_critical.csv"))
    t["lillie_n"] = np.array(_unique(lil["n"]), dtype=float)
    t["lillie_p"] = np.array(_unique(lil["p"]), dtype=float)
    t["lillie"] = lil["value"].to_numpy(dtype=float).reshape(
        (len(t["lillie_n"]), len(t["lillie_p"])), order="F")
    return t
