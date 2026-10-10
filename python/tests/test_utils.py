import numpy as np
import pandas as pd
import pytest
from scipy import stats

import tsexplorer as tsx
from tsexplorer._utils_input import tsx_remove_nan
from tsexplorer._utils_math import (tsx_auxvarsbc, tsx_delay, tsx_fminsearch, tsx_ksdensity,
                                    tsx_mvar, tsx_nancov, tsx_prctile, tsx_signrank,
                                    tsx_standardize)
from tsexplorer._vboxcox import tsx_guerrero

from conftest import data, expect_equal, expect_ref, ref, ref_input, values


def test_as_tsx_matrix_converts_the_supported_inputs():
    y, names, _ = tsx.as_tsx_matrix(np.arange(1, 11))
    assert y.shape == (10, 1)
    assert names == ["#1"]
    df = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})
    assert tsx.as_tsx_matrix(df)[1] == ["a", "b"]
    assert tsx.as_tsx_matrix(np.arange(6).reshape(3, 2), names="x y")[1] == ["x", "y"]
    assert tsx.as_tsx_matrix(np.arange(9).reshape(3, 3), names="x")[1] == ["x", "#2", "#3"]
    assert tsx.as_tsx_matrix(data("airpas"))[0].shape[0] == 144
    assert tsx.as_tsx_matrix(pd.DataFrame({"u": [1, 2, 3], "v": [3, 2, 1]}))[1] == ["u", "v"]
    assert tsx.as_tsx_matrix(data("lydia_pinkham"))[1] == ["advertising", "sales"]
    # a named Series keeps its name; a DataFrame built from a matrix has no names
    assert tsx.as_tsx_matrix(pd.Series([1.0, 2.0], name="z"))[1] == ["z"]
    assert tsx.as_tsx_matrix(pd.DataFrame(np.ones((3, 2))))[1] == ["#1", "#2"]


def test_as_tsx_matrix_removes_missing_rows_at_the_ends_only():
    y = np.column_stack([[np.nan, np.nan, 1, np.nan, 3, np.nan],
                         [np.nan, 2, 1, np.nan, 3, np.nan]])
    out = tsx.as_tsx_matrix(y)[0]
    assert out.shape[0] == 4
    assert list(tsx_remove_nan(y)[1]) == [1, 2, 3, 4]
    assert tsx.as_tsx_matrix(y, trim=False)[0].shape[0] == 6
    assert list(tsx.as_tsx_matrix([np.nan, 1, 2])[0].ravel()) == [1, 2]


def test_invalid_inputs_give_clear_errors():
    with pytest.raises(ValueError, match="numeric"):
        tsx.as_tsx_matrix("a")
    with pytest.raises(ValueError, match="numeric"):
        tsx.as_tsx_matrix(pd.DataFrame({"a": [1, 2, 3], "b": ["a", "b", "c"]}))
    with pytest.raises(ValueError, match="missing"):
        tsx.as_tsx_matrix([np.nan, np.nan])
    airpas = data("airpas")
    with pytest.raises(ValueError, match="series"):
        tsx.vident(airpas, series=3)
    with pytest.raises(ValueError, match="not found"):
        tsx.vident(airpas, series="zz")
    with pytest.raises(ValueError, match="two series"):
        tsx.vident2(airpas)
    with pytest.raises(ValueError, match="two series"):
        tsx.vgranger(airpas)
    with pytest.raises(ValueError, match="ncoef"):
        tsx.vident(airpas, ncoef=-1)


def test_utilities_match_the_reference_values():
    u = ref("utilities")
    expect_ref(tsx.vdif(data("la"), [1, 1], [1, 12]), u["vdif_la"])
    lp = values(data("lp"))
    expect_ref(tsx.vdif(np.hstack([lp, lp]), [[1, 0], [1, 1]], [1, 12]), u["vdif_lp"])
    sv = ref_input("sim_var3.csv")
    expect_ref(tsx_delay(sv[:10, :], [0, 1, 3]), u["delay"])
    expect_ref(tsx_prctile(values(data("scc")), [10, 25, 50, 75, 90]), u["prctile"])
    expect_ref(tsx_standardize(sv[:10, :]), u["transform"])
    sn = ref_input("sim_na.csv")
    expect_ref(tsx_nancov(sn[:30, :]), u["nancov"])
    expect_ref(tsx.meda(data("scc")), u["meda"])
    v = tsx_mvar(sv - sv.mean(axis=0), [1, 2], True)
    expect_ref(v["p"], u["mvar_p"])
    expect_ref(v["sigma"], u["mvar_sigma"])
    expect_ref([v["aic"], v["sbc"]], [u["mvar_aic"], u["mvar_sbc"]])
    dla = values(data("dla"))
    a = tsx_auxvarsbc(dla - dla.mean(), 3)
    expect_ref(np.r_[a["fpe"], a["aic"], a["aicc"], a["sbc"], a["hqc"], a["sigma"].ravel()],
               u["auxvarsbc"])
    expect_ref(tsx_ksdensity(dla.ravel(), u["ksdensity_x"]), u["ksdensity"])


def test_the_nelder_mead_simplex_matches_the_reference_values():
    u = ref("utilities")
    a = values(data("airpas")).ravel()
    g = tsx_fminsearch(lambda l: tsx_guerrero(l[0], a, 12), 1)
    expect_ref(g["par"], u["fminsearch_guerrero"])
    r = tsx_fminsearch(lambda x: 100 * (x[1] - x[0] ** 2) ** 2 + (1 - x[0]) ** 2, [-1.2, 1])
    expect_ref(r["par"], u["fminsearch_rosen"])


def test_the_signed_rank_test_matches_the_reference_values():
    u = np.array(ref("utilities")["signrank"])
    sr = ref_input("sim_signrank.csv")
    # exact (n <= 15) and normal approximation with ties
    expect_ref(tsx_signrank(sr[:10, 0], sr[:10, 1])[::-1], u[0, :])
    expect_ref(tsx_signrank(sr[:, 0], sr[:, 1])[::-1], u[1, :])
    # without ties the exact p-value equals the exact Wilcoxon test
    x = np.array([1.83, 0.50, 1.62, 2.48, 1.68, 1.88, 1.55, 3.06, 1.30])
    y = np.array([0.878, 0.647, 0.598, 2.05, 1.06, 1.29, 1.06, 3.14, 1.29])
    w = tsx_signrank(x, y)
    expect_equal(w[1], stats.wilcoxon(x, y, method="exact").pvalue)


def test_adfcritical_interpolates_the_dickey_fuller_tables():
    # exact at the tabulated points
    expect_equal(tsx.adfcritical(-2.89, 100, "t_const"), 0.05)
    expect_equal(tsx.adfcritical(-3.45, 100, "t_trend"), 0.05)
    expect_equal(tsx.adfcritical(4.71, 100, "f_const"), 0.05)
    assert list(tsx.adfcritical([-10, 10], 100, "t_none")) == [0, 1]
    assert list(tsx.adfcritical([0, 50], 100, "f_trend")) == [1, 0]
    # linear interpolation on the stored triangulation
    u = ref("utilities")
    tabs = ["t_none", "t_const", "t_trend", "f_const", "f_trend"]
    expected = np.array(u["adfcritical"])
    for d in range(5):
        g = np.array([tsx.adfcritical(u["adfcritical_x"], tt, tabs[d])
                      for tt in u["adfcritical_t"]])
        expect_ref(g, expected[d, :, :], tolerance=1e-10)
    with pytest.raises(ValueError, match="table"):
        tsx.adfcritical(1, 100, "zz")
