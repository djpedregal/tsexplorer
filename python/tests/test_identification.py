import math

import numpy as np
from scipy import stats

import tsexplorer as tsx

from conftest import data, expect_equal, expect_ref, ref, ref_input, values


def check_vident(r, x):
    t = r.table
    expect_ref(t[["acf", "se_acf", "q_lb", "p_lb", "pacf", "se_pacf", "q_mt", "p_mt"]],
               np.column_stack([x["sacf"], x["seacf"], x["Q"], x["PQ"], x["spacf"],
                                x["sepacf"], x["Qmt"], x["PQmt"]]))


def test_vident_matches_the_reference_values():
    v = ref("vident")
    check_vident(tsx.vident(data("dla")), v["dla"])
    check_vident(tsx.vident(data("dla"), 24, npar=2), v["dla_npar2"])
    check_vident(tsx.vident(ref_input("sim_na.csv"), 20), v["sim_na"])
    check_vident(tsx.vident(data("scc"), 10, series=2), v["scc_2"])
    check_vident(tsx.vident(data("scc"), 10, series="y2"), v["scc_2"])


def _acf(x, nlags):
    x = x - x.mean()
    den = np.sum(x ** 2)
    return np.array([np.sum(x[:-k] * x[k:]) / den for k in range(1, nlags + 1)])


def test_vident_default_lags_degrees_of_freedom_and_direct_computations():
    r = tsx.vident(data("dla"))
    assert r.call["ncoef"] == min(38, math.ceil(131 / 4 * 2))
    r = tsx.vident(data("dla"), 12, npar=2)
    assert r.table["p_lb"][:2].isna().all()
    x = values(data("dla")).ravel()
    a = _acf(x, 12)
    expect_equal(r.table["acf"], a, tolerance=1e-10)
    # Ljung-Box statistic with 12 - 2 degrees of freedom
    n = len(x)
    q = n * (n + 2) * np.sum(a ** 2 / (n - np.arange(1, 13)))
    expect_equal(r.table["q_lb"][11], q, tolerance=1e-10)
    expect_equal(r.table["p_lb"][11], stats.chi2.sf(q, 10), tolerance=1e-10)


def check_vident2(r, x):
    m = len(r.series)
    nc = r.call["ncoef"]

    def blk(arr):
        return np.vstack([arr[:, :, k] for k in range(nc + 1)])

    d = np.array(x["data"])
    expect_ref(blk(r.acf), d[:, :m])
    expect_ref(blk(r.pacf), d[:, m:2 * m])
    expect_ref(np.hstack([blk(r.se_acf), blk(r.se_pacf)]), d[:, 2 * m:4 * m])
    # column 5 (p_q) is not compared
    expect_ref(r.stats[["aic", "sbc", "chi", "p_chi", "det_sigma"]],
               np.array(x["stats"])[:, [0, 1, 2, 3, 5]])
    # Hosking (1980) / Li-McLeod (1981) portmanteau computed directly
    r0i = np.linalg.inv(r.acf[:, :, 0])
    n = round(1 / r.se_acf[0, 0, 0] ** 2)
    cum = np.cumsum([np.trace(r.acf[:, :, k].T @ r0i @ r.acf[:, :, k] @ r0i)
                     for k in range(1, nc + 1)])
    k = np.arange(1, nc + 1)
    q = n * cum + m ** 2 * k * (k + 1) / (2 * n)
    df = m ** 2 * (k - r.call["npar"])
    expected = np.where(df > 0, stats.chi2.sf(q, np.maximum(df, 1)), np.nan)
    expect_equal(r.stats["p_q"], expected)


def test_vident2_matches_the_reference_values():
    v = ref("vident2")
    check_vident2(tsx.vident2(data("dlp"), 8, type=0), v["dlp_type0"])
    check_vident2(tsx.vident2(data("dlp"), 8, type=1), v["dlp_type1"])
    check_vident2(tsx.vident2(ref_input("sim_var3.csv"), 6, npar=1), v["simvar_type0"])


def test_varsbc_and_varsbc2_match_the_reference_values():
    v = ref("varsbc")
    expect_ref(tsx.varsbc(data("dla"), 15).table.iloc[:, 1:], v["dla"]["data"])
    expect_ref(tsx.varsbc(data("scc"), 5, series="all").table.iloc[:, 1:], v["scc_all"]["data"])
    expect_ref(tsx.varsbc2(data("dla"), 12).table["sbc"], v["varsbc2_dla"]["sbc"])
    r = tsx.varsbc(data("dla"), 15)
    assert r.best["sbc"] == int(np.argmin(np.array(v["dla"]["data"])[:, 1]))


def test_varsbc_with_one_series_of_several_uses_the_dimension_of_the_model():
    # The LR statistic and its degrees of freedom use the number of series in
    # the model.
    v = ref("varsbc")
    r = tsx.varsbc(data("scc"), 5, series=2)
    expect_ref(r.table[["aicc", "sbc", "hqc"]], np.array(v["scc_2"]["data"])[:, :3])
    r1 = tsx.varsbc(values(data("scc"))[:, 1], 5)
    assert r.table.equals(r1.table)


def test_vgranger_matches_the_reference_values():
    # Covariance of the coefficients: kron(inv(X'X), Sigma).
    v = ref("vgranger")
    cols = ["constraints", "f", "p_f", "chi2", "p_chi2"]
    r = tsx.vgranger(data("dlp"), [1, 2, 3])
    assert list(r.table["test"]) == v["dlp"]["tests"]
    expect_ref(r.table[cols], v["dlp"]["table_fixed"])
    sv = ref_input("sim_var3.csv")
    expect_ref(tsx.vgranger(sv, [1, 2]).table[cols], v["simvar"]["table_fixed"])
    expect_ref(tsx.vgranger(sv, [1, 3], "a-bc bc-a").table[cols],
               v["simvar_block"]["table_fixed"])


def test_vgranger_agrees_with_a_single_equation_wald_test():
    # With one constraint block in one equation, the Wald statistic equals the
    # one computed from the OLS estimation of that equation.
    y = values(data("dlp"))
    y = y - y.mean(axis=0)
    n = y.shape[0]
    x = np.hstack([y[1:n - 1, :], y[:n - 2, :]])
    yy = y[2:, 0]
    b, *_ = np.linalg.lstsq(x, yy, rcond=None)
    e = yy - x @ b
    sig = np.sum(e ** 2) / n
    bb = b[[1, 3]]
    vv = np.linalg.inv(x.T @ x)[np.ix_([1, 3], [1, 3])] * sig
    w = bb @ np.linalg.solve(vv, bb)
    r = tsx.vgranger(data("dlp"), [1, 2], "a-b")
    expect_equal(r.table["chi2"][0], w, tolerance=1e-10)
    assert r.table["h0"][0] == "sales does not cause advertising"
