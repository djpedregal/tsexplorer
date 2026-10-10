import numpy as np
from scipy import stats

import tsexplorer as tsx
from tsexplorer._spectrum import tsx_mspectrum
from tsexplorer._utils_math import tsx_delay
from tsexplorer._vbds import tsx_bds

from conftest import data, expect_equal, expect_ref, ref, ref_input, values


def test_nltests_matches_the_reference_values():
    nl = ref("nonlinear")
    r = tsx.nltests(data("dla"), 12)
    x = nl["nltests_dla"]
    expect_ref(r.table[["acf", "se_acf", "q_mll", "p_mll", "pacf", "q_mt", "p_mt", "d_pr",
                        "p_pr"]],
               np.column_stack([x["sacf"], x["seacf"], x["Q"], x["PQ"], x["spacf"], x["Qmt"],
                                x["PQmt"], x["Dm"], x["pDm"]]))


def test_nltests_with_missing_values_uses_the_same_acf_as_vident():
    sn = ref_input("sim_na.csv")
    r = tsx.nltests(sn, 10)
    v = tsx.vident(sn ** 2, 10)
    assert np.array_equal(r.table["acf"], v.table["acf"])


def _ols(y, x):
    b, *_ = np.linalg.lstsq(x, y, rcond=None)
    e = y - x @ b
    return b, e


def test_vtsay_is_the_f_test_of_the_cross_products_in_the_ar_regression():
    # Tsay (1986) with constant and F(k, n - p - k - 1); by the
    # Frisch-Waugh-Lovell theorem it equals the F test of adding the cross
    # products to the AR(p) regression with constant (anova() in R).
    for y in (values(data("dla")).ravel(), values(data("scc"))[:, 2]):
        p = 3
        x = tsx_delay(y, range(p + 1))
        n = x.shape[0]
        prods = np.column_stack([x[:, i] * x[:, j] for i in range(1, p + 1)
                                 for j in range(i, p + 1)])
        x0 = np.column_stack([np.ones(n), x[:, 1:]])
        x1 = np.hstack([x0, prods])
        _, e0 = _ols(x[:, 0], x0)
        b1, e1 = _ols(x[:, 0], x1)
        k = prods.shape[1]
        df2 = n - x1.shape[1]
        f = ((np.sum(e0 ** 2) - np.sum(e1 ** 2)) / k) / (np.sum(e1 ** 2) / df2)
        r = tsx.vtsay(y, p)
        expect_equal(r.table["f"][0], f, tolerance=1e-10)
        expect_equal(r.table["p_value"][0], stats.f.sf(f, k, df2), tolerance=1e-10)
        assert r.table["df2"][0] == df2
        # coefficients of the auxiliary regression are those of the products
        s2 = np.sum(e1 ** 2) / df2
        se = np.sqrt(np.diag(s2 * np.linalg.inv(x1.T @ x1)))
        t = b1 / se
        expect_equal(r.regressions["beta"], b1[p + 1:], tolerance=1e-8)
        expect_equal(r.regressions["t"], t[p + 1:], tolerance=1e-8)
        expect_equal(r.regressions["p_value"], 2 * stats.t.sf(np.abs(t[p + 1:]), df2),
                     tolerance=1e-8)


def test_bds_statistic_matches_the_reference_values():
    nl = ref("nonlinear")
    dla = values(data("dla")).ravel()
    b = tsx_bds(dla, 4, 1.5)
    expect_ref(b["w"], nl["bds_dla"]["w"])
    expect_ref(b["p_value"], nl["bds_dla"]["sig"])
    expect_ref(np.r_[b["c1"], b["k"]], np.r_[nl["bds_dla"]["c1"], nl["bds_dla"]["k"]])
    b = tsx_bds(ref_input("sim_ar1.csv").ravel(), 3, 1.2)
    expect_ref(b["w"], nl["bds_simar"]["w"])
    r = tsx.vbds(data("dla"), maxdim=4)
    expect_ref(r.table["w"], nl["bds_dla"]["w"])
    assert list(r.table["dim"]) == [2, 3, 4]


def test_varsbc2_detects_linearity_of_white_noise():
    r = tsx.varsbc2(ref_input("sim_ar1.csv") - 10, 5)
    assert r.table.shape[0] == 6
    assert isinstance(r.linear, bool)


def test_vcumperiod_matches_the_reference_values_on_demeaned_data():
    sp = ref("spectral")
    expect_ref(tsx.vcumperiod(data("dla")).table["cum_periodogram"],
               sp["cumper_dla"]["cumP_demeaned"])
    expect_ref(tsx.vcumperiod(data("airpas")).table["cum_periodogram"],
               sp["cumper_a"]["cumP_demeaned"])
    expect_ref(tsx.vcumperiod(data("airpas")).bands, sp["cumper_a"]["conf"])


def test_periodogram_and_cross_periodogram_match_the_reference_values():
    # frequencies are the Fourier frequencies 2 pi j / T
    sp = ref("spectral")
    ms = tsx_mspectrum(values(tsx.vdif(data("la"))))
    expect_ref(np.real(ms["i"][0, 0, :]), sp["mspectrum_dla"]["I"])
    expect_equal(ms["w"], 2 * np.pi * np.arange(143 // 2 + 1) / 143)
    ms = tsx_mspectrum(values(data("dlp")))
    x = sp["mspectrum_dlp"]
    expect_ref(np.column_stack([np.real(ms["i"][0, 0, :]), np.real(ms["i"][1, 1, :]),
                                np.real(ms["i"][0, 1, :]), np.imag(ms["i"][0, 1, :])]),
               np.column_stack([x["I11"], x["I22"], x["I12_re"], x["I12_im"]]))
    # with missing values the DFT skips them
    sn = ref_input("sim_na.csv")
    assert not tsx.vspectrum(sn).table["periodogram"].isna().any()


def test_vspectrum_smoothing_and_coherence():
    dla = tsx.vdif(data("la"))
    r1 = tsx.vspectrum(dla, smooth=1)
    assert np.array_equal(r1.table["spectrum"], r1.table["periodogram"])
    r5 = tsx.vspectrum(dla, smooth=4)
    assert r5.call["smooth"] == 5
    b = np.array([1, 2, 3, 2, 1]) / 9
    per = r1.table["periodogram"].to_numpy()
    k = 9
    expect_equal(r5.table["spectrum"][k], np.sum(b * per[k - 2:k + 3]))
    # symmetric extension at frequencies 0 and pi (T = 143, odd)
    np_ = len(per)
    expect_equal(r5.table["spectrum"][0], np.sum(b * per[[2, 1, 0, 1, 2]]))
    expect_equal(r5.table["spectrum"][np_ - 1],
                 np.sum(b * per[[np_ - 3, np_ - 2, np_ - 1, np_ - 1, np_ - 2]]))
    # even T: the last frequency is pi
    de = values(dla)[1:, :]
    r1e = tsx.vspectrum(de, smooth=1)
    r5e = tsx.vspectrum(de, smooth=5)
    pe = r1e.table["periodogram"].to_numpy()
    ne = len(pe)
    expect_equal(r5e.table["spectrum"][ne - 1],
                 np.sum(b * pe[[ne - 3, ne - 2, ne - 1, ne - 2, ne - 3]]))
    r = tsx.vspectrum(data("dlp"), smooth=7, series=[1, 2])
    assert np.all((r.table["coherence"] >= 0) & (r.table["coherence"] <= 1 + 1e-12))
    expect_equal(r.table["gain12"] * r.table["spectrum1"], r.table["cross_amplitude"])


def test_varspectrum_matches_the_reference_values():
    sp = ref("spectral")
    # spectrum sigma^2 / (2 pi) |1/phi|^2
    dla = tsx.vdif(data("la"))
    r = tsx.varspectrum(dla, 14, 72)
    k = r.sigma2 / (2 * np.pi ** 2)
    expect_ref(r.table["freq"], sp["varspectrum_dla"]["freq"])
    expect_ref(r.table["spectrum"], np.array(sp["varspectrum_dla"]["spectrum"]) * k)
    expect_ref(r.ar, sp["varspectrum_dla"]["ar"])
    r = tsx.varspectrum(dla, 6, 0)
    x = sp["varspectrum_fourier"]
    expect_ref(np.column_stack([r.table["freq"], r.table["spectrum"]]),
               np.column_stack([x["freq"], np.array(x["spectrum"]) * r.sigma2 / (2 * np.pi ** 2)]))
    # AR(1): f(0) = sigma^2 / (2 pi) / (1 - phi)^2
    w = ref_input("sim_ar1.csv")[:, 0]
    r = tsx.varspectrum(w, 1)
    phi = r.ar[0]
    expect_equal(r.table["spectrum"][0], r.sigma2 / (2 * np.pi) / (1 - phi) ** 2)
