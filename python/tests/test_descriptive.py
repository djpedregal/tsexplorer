import numpy as np
from scipy import stats

import tsexplorer as tsx

from conftest import data, expect_equal, expect_ref, ref, ref_input, values


def test_sumstats_matches_the_reference_values():
    s = ref("sumstats")
    for nm in ("airpas", "scc", "sim_na"):
        y = ref_input("sim_na.csv") if nm == "sim_na" else data(nm)
        r = tsx.sumstats(y)
        v = np.array(s[nm]["value"]).reshape(22, -1)
        # rows 7 (P(mean = 0)) and 15 (range) are checked separately
        # the mode (row 11) is not in the MATLAB output
        vals = r.stats.iloc[:, 1:].to_numpy(dtype=float).T
        vals = np.delete(vals, 10, axis=0)
        keep = [k for k in range(22) if k not in (6, 14)]
        expect_ref(vals[keep, :], v[keep, :])
        # two sided p-value (twice the one sided value)
        expect_ref(r.stats["p_mean_zero"], 2 * v[6, :])
        # range is max - min
        expect_ref(r.stats["range"], v[12, :] - v[2, :])
        if r.cor is not None:
            expect_ref(r.cor, s[nm]["corr"])
    x = values(data("airpas")).ravel()
    expect_equal(tsx.sumstats(x - 280).stats["p_mean_zero"][0],
                 stats.ttest_1samp(x - 280, 0).pvalue)


def test_sumstats_structure_one_and_several_series_bootstrap():
    r1 = tsx.sumstats(data("airpas"))
    assert r1["class"] == ["tsx_sumstats", "tsx_result"]
    assert r1.cor is None
    assert r1.stats.shape[0] == 1
    r3 = tsx.sumstats(data("scc"))
    assert r3.cor.shape == (3, 3)
    assert r1.stats["median"][0] == np.median(values(data("airpas")))
    # mode: most frequent value, the smallest one in case of ties (MATLAB mode)
    assert tsx.sumstats([3, 1, 2, 2, 3, np.nan]).stats["mode"][0] == 2
    assert tsx.sumstats([5, 4, 4, 5, 9]).stats["mode"][0] == 4
    assert tsx.sumstats([2.5, 1.5, 3]).stats["mode"][0] == 1.5
    b1 = tsx.sumstats(data("airpas"), gaussian=False, nsimul=200, seed=1)
    b2 = tsx.sumstats(data("airpas"), gaussian=False, nsimul=200, seed=1)
    assert b1.stats["p_mean_zero"][0] == b2.stats["p_mean_zero"][0]
    assert 0 <= b1.stats["p_mean_zero"][0] <= 1


def test_gausstest_matches_the_reference_values():
    g = ref("gausstest")
    for nm in ("dla", "scc", "nile"):
        r = tsx.gausstest(data(nm))
        x = g[nm]
        expect_ref(np.column_stack([r.table["skewness"], r.table["kurtosis"]]),
                   np.column_stack([np.atleast_1d(x["skew"]), np.atleast_1d(x["kurto"])]))
        expect_ref(np.column_stack([r.table["bj"], r.table["p_bj"]]),
                   np.column_stack([np.atleast_1d(x["beraj"]), np.atleast_1d(x["pvalue"])]))
        # Kolmogorov-Smirnov statistic max(D+, D-) (reference 'D_full').
        expect_ref(np.column_stack([r.table["ksl"], r.table["p_ksl"]]),
                   np.column_stack([np.atleast_1d(x["D_full"]), np.atleast_1d(x["Dc_full"])]))
    r = tsx.gausstest(data("scc"))
    expect_ref([r.bj_multi, r.p_bj_multi], [g["scc"]["vBJ"], g["scc"]["PvBJ"]])


def test_gausstest_with_missing_values_uses_the_number_of_observations():
    # The Bera-Jarque statistic uses the number of non missing observations.
    g = ref("gausstest")
    sn = ref_input("sim_na.csv")
    r = tsx.gausstest(sn)
    n = np.sum(~np.isnan(sn))
    assert r.table["n"][0] == n
    expect_ref(r.table["bj"], g["sim_na"]["beraj"] * n / g["sim_na"]["T"])
    # KS statistic is the classical one (agrees with scipy.stats.kstest)
    x = values(data("dla")).ravel()
    d = stats.kstest(x, stats.norm(x.mean(), x.std(ddof=1)).cdf).statistic
    expect_equal(tsx.gausstest(x).table["ksl"][0], d)


def test_vhist_and_vqqplot_return_the_plotted_data():
    dla = data("dla")
    h = tsx.vhist(dla, bins=10)
    assert h.hist["count"].sum() == len(dla)
    assert h.density.shape[0] == 181
    q = tsx.vqqplot(dla)
    gr = ref("graphics")
    expect_ref(np.column_stack([q.table["theoretical"], q.table["empirical"]]),
               np.column_stack([gr["vqqplot_dla"]["qtheo"], gr["vqqplot_dla"]["zi"]]))
    # reference line through the quartiles of the data
    expect_ref(q.line["y"], [gr["vqqplot_dla"]["yini_fixed"], gr["vqqplot_dla"]["yend_fixed"]])
    # missing values are dropped before computing the plotting positions
    sn = ref_input("sim_na.csv")
    assert tsx.vqqplot(sn).table.shape[0] == np.sum(~np.isnan(sn))


def test_boxplots_stdmean_and_vcusum_match_the_reference_values():
    gr = ref("graphics")
    airpas = data("airpas")
    expect_ref(tsx.vboxplot(airpas).stats.iloc[:, 1:], gr["boxplot_a"]["box"])
    r = tsx.vtboxplot(airpas)
    expect_ref(r.stats.iloc[:, 1:], gr["boxplot_a"]["tbox"])
    expect_ref(r.data, gr["boxplot_a"]["tdata"])
    for k in range(3):
        r = tsx.stdmean(airpas, 12, k)
        x = gr["stdmean_a%d" % k]
        expect_ref(np.column_stack([r.table["location"], r.table["dispersion"]]), x["data"])
        expect_ref(r.coef, x["beta"])
    r = tsx.vcusum(data("dla"))
    t = r.table
    x = gr["vcusum_dla"]
    expect_ref(np.column_stack([t["cusum"], t["cusumsq"], t["cusum_upper"], t["cusumsq_lower"],
                                t["cusumsq_upper"]]),
               np.column_stack([x["cusum"], x["cusumsq"], x["band"], x["bandsq"]]))


def test_plotband_and_vscatter_return_the_plotted_data():
    airpas = data("airpas")
    a = values(airpas).ravel()
    p = tsx.plotband(airpas, s=12, subsample=2)
    assert list(p.time) == list(range(13, 25))
    assert list(p.data.ravel()) == list(a[12:24])
    expect_equal(p.mean, a.mean())
    o = tsx.plotband(airpas, overlay=True)
    assert o.data.shape == (12, 12)
    al = tsx.plotband(data("scc"), series="all", standard=True)
    assert al.data.shape[1] == 3
    v = tsx.vscatter(data("scc"))
    assert v.coef.shape[0] == 6
    b = v.coef[(v.coef["x"] == "y1") & (v.coef["y"] == "y2")]
    scc = values(data("scc"))
    fit = stats.linregress(scc[:, 0], scc[:, 1])
    expect_equal([b["intercept"].iloc[0], b["slope"].iloc[0]], [fit.intercept, fit.slope])
