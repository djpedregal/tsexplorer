import numpy as np
import pytest

import tsexplorer as tsx
from tsexplorer._adftest import tsx_unitroot_lags
from tsexplorer._johansentest import tsx_johansen_p

from conftest import data, expect_equal, expect_ref, ref, ref_input, values


def _v(x):
    return np.atleast_1d(np.asarray(x, dtype=float))


def check_adf(r, x):
    expect_ref(r.none[["rho", "t"]], np.column_stack([_v(x["Rhont"]), _v(x["tRhont"])]))
    expect_ref(r.const[["rho", "t", "const", "t_const"]],
               np.column_stack([_v(x["Rho"]), _v(x["tRho"]), _v(x["Alfa"]), _v(x["tAlfa"])]))
    expect_ref(r.trend[["rho", "t", "const", "t_const", "trend", "t_trend"]],
               np.column_stack([_v(x["Rhot"]), _v(x["tRhot"]), _v(x["Alfat"]),
                                _v(x["tAlfat"]), _v(x["D"]), _v(x["tD"])]))
    # F statistics divided by the number of restrictions and
    # Phi3 computed with the coefficient of the model with trend.
    expect_ref(r.const["f"], _v(x["F_fixed"]))
    expect_ref(r.trend["f"], _v(x["Ft_fixed"]))
    # p-values of the t statistics (stored triangulation)
    expect_ref(np.column_stack([r.none["p_t"], r.const["p_t"], r.trend["p_t"]]),
               np.column_stack([_v(x["p_tRhont"]), _v(x["p_tRho"]), _v(x["p_tRhot"])]))


def test_adftest_matches_the_reference_values():
    ad = ref("adftest")
    check_adf(tsx.adftest(data("la"), [1, 2, 3, 4]), ad["la"])
    check_adf(tsx.adftest(data("lp"), 3), ad["lp"])
    check_adf(tsx.adftest(data("nile"), [1, 2]), ad["nile"])


def test_adftest_lags_structure_and_direct_computations():
    r = tsx.adftest(data("la"))
    assert r.call["lags"] == list(range(1, 13))
    r = tsx.adftest(data("lp"))
    assert r.call["lags"] == [7]
    assert r.const.shape[0] == 2
    assert tsx_unitroot_lags(100, 144, 1) == [72]
    with pytest.raises(ValueError, match="lags"):
        tsx.adftest(data("la"), 100)
    # t statistic of the ADF regression with trend and 3 lags, computed
    # directly (as urca::ur.df in the R tests)
    z = values(data("la")).ravel()
    n = len(z)
    p = 3
    dz = np.diff(z)
    rows = np.arange(p + 1, n)
    x = np.column_stack([z[rows - 1], np.ones(len(rows)), np.arange(1, len(rows) + 1)]
                        + [dz[rows - 1 - j] for j in range(1, p + 1)])
    b, *_ = np.linalg.lstsq(x, z[rows], rcond=None)
    e = z[rows] - x @ b
    cov = np.sum(e ** 2) / (len(rows) - x.shape[1]) * np.linalg.inv(x.T @ x)
    r = tsx.adftest(data("la"), 3)
    expect_equal(r.trend["t"][0], (b[0] - 1) / np.sqrt(cov[0, 0]), tolerance=1e-8)


def test_vphillips_matches_the_reference_values():
    # the correction term is divided by the standard error of the regression
    pp = ref("vphillips")
    for nm in ("la", "lp"):
        r = tsx.vphillips(data("la"), [1, 2, 3], 4) if nm == "la" else tsx.vphillips(data("lp"), 3)
        x = pp[nm]
        expect_ref(np.column_stack([r.none["rho"], r.const["rho"], r.trend["rho"]]),
                   np.column_stack([_v(x["rho_none"]), _v(x["rho_const"]), _v(x["rho_trend"])]))
        expect_ref(np.column_stack([r.none["z_t"], r.const["z_t"], r.trend["z_t"]]),
                   np.column_stack([_v(x["z_none_fixed"]), _v(x["z_const_fixed"]),
                                    _v(x["z_trend_fixed"])]))
    # each model uses its own statistic for the p-value
    r = tsx.vphillips(data("la"), [1, 2, 3], 4)
    assert np.array_equal(r.const["p_value"], tsx.adfcritical(r.const["z_t"], r.n, "t_const"))
    assert np.array_equal(r.trend["p_value"], tsx.adfcritical(r.trend["z_t"], r.n, "t_trend"))


def test_vphillips_without_lags_agrees_with_the_textbook_statistic():
    # Z(t) of Phillips and Perron (1988) with Bartlett weights, computed directly
    z = values(data("la")).ravel()
    n = len(z)
    r = tsx.vphillips(z, lags=0, ncovs=4)
    y = z[1:]
    x = np.column_stack([z[:-1], np.ones(n - 1)])
    b, *_ = np.linalg.lstsq(x, y, rcond=None)
    e = y - x @ b
    s2 = np.sum(e ** 2) / (len(e) - 2)
    se = np.sqrt(s2 * np.linalg.inv(x.T @ x)[0, 0])
    t0 = (b[0] - 1) / se
    g0 = np.sum(e ** 2) / n
    lam = g0
    for k in range(1, 5):
        lam += 2 * (1 - k / 5) * np.sum(e[k:] * e[:len(e) - k]) / n
    zt = np.sqrt(g0 / lam) * t0 - 0.5 * (lam - g0) / np.sqrt(lam) * n * se / np.sqrt(s2)
    expect_equal(r.const["z_t"][0], zt, tolerance=1e-10)


def test_johansentest_matches_the_reference_values():
    jo = ref("johansentest")
    # p-values of the models with constant and trend are checked below
    cols = ["stat_none", "p_none", "stat_const", "stat_trend"]
    ref_cols = [0, 1, 2, 4]
    r = tsx.johansentest(data("lp"), 3)
    expect_ref(r.table[cols], np.array(jo["lp"]["table"])[:, ref_cols])
    expect_ref(r.eigen.iloc[:, 1:], jo["lp"]["table2"])
    assert list(r.table["type"]) == ["max", "trace", "max"]
    expect_ref(tsx.johansentest(data("la"), [2, 3, 4]).table[cols],
               np.array(jo["la"]["table"])[:, ref_cols])
    sv = np.cumsum(ref_input("sim_var3.csv"), axis=0)
    r = tsx.johansentest(sv, 2)
    expect_ref(r.table[cols], np.array(jo["simvar"]["table"])[:, ref_cols])
    assert r.table["p_trend"].isna().all()


def test_johansentest_p_values_use_the_tables_of_each_model():
    # 5% critical values of Johansen-Juselius (1990), Table A1 (unrestricted
    # constant) and Osterwald-Lenum (1992), Table 0 (no deterministic terms)
    expect_equal(tsx_johansen_p([3.962, 14.036, 15.197, 29.509], [1, 2, 2, 3],
                                ["max", "max", "trace", "trace"], 3), [0.05] * 4)
    expect_equal(tsx_johansen_p([11.44, 12.53], [2, 2], ["max", "trace"], 1), [0.05, 0.05])
    r = tsx.johansentest(data("lp"), 3)
    assert np.array_equal(r.table["p_const"],
                          tsx_johansen_p(r.table["stat_const"], 2 - r.table["h0"],
                                         r.table["type"], 3))


def test_johansentest_eigenvalues_are_those_of_the_reduced_rank_regression():
    # eigenvalues with a constant: canonical correlations between the
    # residuals of dz(t) and z(t-1) on the lagged differences and a constant
    # (as urca::ca.jo(ecdet = "none", spec = "transitory") in the R tests)
    y = values(data("lp"))
    n = y.shape[0]
    dz = np.diff(y, axis=0)
    x = np.column_stack([dz[1:-1], dz[:-2], np.ones(n - 3)])
    u = dz[2:] - x @ np.linalg.lstsq(x, dz[2:], rcond=None)[0]
    v = y[2:-1] - x @ np.linalg.lstsq(x, y[2:-1], rcond=None)[0]
    suu, svv, suv = u.T @ u, v.T @ v, u.T @ v
    lam = np.sort(np.real(np.linalg.eigvals(
        np.linalg.solve(svv, suv.T) @ np.linalg.solve(suu, suv))))[::-1]
    expect_equal(tsx.johansentest(y, 3).eigen["eigen_const"], lam, tolerance=1e-8)
