# Helpers of the tests (helper-reference.R in the R version): stored reference
# results, shared input data and comparison with all.equal() semantics.

import json
import os

import matplotlib
import numpy as np
import pandas as pd
import pytest

import tsexplorer as tsx

# plots without windows (the tests of the windows use their own figures)
matplotlib.use("Agg")

REF_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "r", "inst", "extdata",
                       "reference")


def ref(name):
    """Stored reference results (r/inst/extdata/reference/<name>.json, shared
    with the R and MATLAB versions)."""
    f = os.path.join(REF_DIR, name + ".json")
    if not os.path.exists(f):
        pytest.skip("Reference file not found: " + name)
    with open(f, encoding="utf-8") as fh:
        return json.load(fh)


def ref_input(file):
    """Shared simulated input data (reference/inputs/<file>) as a matrix."""
    return pd.read_csv(os.path.join(REF_DIR, "inputs", file),
                       na_values=["NA", "NaN"]).to_numpy(dtype=float)


def _tonum(x):
    if isinstance(x, pd.DataFrame):
        x = x.to_numpy(dtype=float)
    elif isinstance(x, pd.Series):
        x = x.to_numpy(dtype=float)
    elif isinstance(x, dict):
        x = list(x.values())
    a = np.asarray(x, dtype=float)
    # column-major order, as unlist()/as.numeric() of R
    return a.ravel(order="F")


def expect_ref(obj, expected, tolerance=1e-6):
    """Compare numbers ignoring names and dimensions, as expect_ref() of the
    R tests (all.equal semantics: the missing values must be in the same
    positions and the mean relative difference of the rest must be <=
    tolerance; the absolute difference when the mean of the expected values
    is <= tolerance)."""
    a = _tonum(obj)
    b = _tonum(expected)
    assert a.size == b.size, "Different number of values: %d and %d" % (a.size, b.size)
    assert np.array_equal(np.isnan(a), np.isnan(b)), "Missing values in different positions."
    ok = ~np.isnan(a) & ~np.isnan(b)
    if not ok.any():
        return
    inf = np.isinf(a) | np.isinf(b)
    assert np.array_equal(a[ok & inf], b[ok & inf]), "Different infinite values."
    x = a[ok & ~inf]
    y = b[ok & ~inf]
    if x.size == 0:
        return
    xy = np.mean(np.abs(y - x))
    xn = np.mean(np.abs(y))
    if np.isfinite(xn) and xn > tolerance:
        xy = xy / xn
    assert xy <= tolerance, "Mean relative difference %g > %g" % (xy, tolerance)


def expect_equal(obj, expected, tolerance=1.5e-8):
    """expect_equal() of testthat for numbers (default tolerance of R)."""
    expect_ref(obj, expected, tolerance)


def data(name):
    """Datasets and transformed data of the tests: the datasets, "la" =
    log(airpas), "lav" = log(airpas) without dates, "dla" = vdif(log(airpas),
    [1, 1], [1, 12]), "lp" = log(lydia_pinkham), "dlp" =
    vdif(log(lydia_pinkham))."""
    if name == "la":
        return np.log(tsx.load_data("airpas"))
    if name == "lav":
        return np.log(tsx.load_data("airpas").to_numpy())
    if name == "dla":
        return tsx.vdif(np.log(tsx.load_data("airpas")), [1, 1], [1, 12])
    if name == "lp":
        return np.log(tsx.load_data("lydia_pinkham"))
    if name == "dlp":
        return tsx.vdif(np.log(tsx.load_data("lydia_pinkham")))
    return tsx.load_data(name)


def values(x):
    """Numeric matrix of a dataset (without names nor dates)."""
    return tsx.as_tsx_matrix(x)[0]
