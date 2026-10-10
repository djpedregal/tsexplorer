import numpy as np
import pandas as pd
import pytest
from scipy import stats

import tsexplorer as tsx
from tsexplorer._forecast import tsx_compare_losses, tsx_forecast_align

from conftest import data, expect_equal, expect_ref, ref, ref_input


def fc():
    return ref_input("sim_fc.csv")


def lav():
    return data("lav")


def test_faccuracy_matches_the_reference_values():
    fo = ref("forecast")
    r = tsx.faccuracy(lav(), fc())
    assert r.call["origin"] == 132
    # columns N, ME (bias), MAE and MASE of the reference
    expect_ref(r.table[["n", "bias", "mae", "mase"]], np.array(fo["trunc1"]["accuracy"])[:, :4])
    h = r.by_horizon[r.by_horizon["forecast"] == 1]
    expect_ref(h[["bias", "mae", "mase"]], np.array(fo["trunc1"]["horizon1"])[:, :3])


def test_comparison_tests_match_the_reference_values():
    # the reference values are computed with percentage error losses
    fo = ref("forecast")
    act = lav()[132:144]
    pe = (fc() - act[:, None]) / act[:, None]
    for tr in (1, 2):
        tab = tsx_compare_losses({"mspe": pe ** 2, "mape": np.abs(pe)}, tr, 12)
        x = fo["trunc%d" % tr]
        ms = tab[tab["loss"] == "mspe"]
        ma = tab[tab["loss"] == "mape"]
        cols = ["sign", "p_sign", "wilcoxon", "p_wilcoxon"]
        expect_ref(ms[cols], np.array(x["mspe"])[:, 2:6])
        expect_ref(ma[cols], np.array(x["mape"])[:, 2:6])
        # long run variance with the autocovariances of lags 1..trunc
        expect_ref(np.column_stack([ms["dm"], ms["p_dm"], ma["dm"], ma["p_dm"]]), x["dm_fixed"])


def test_fcompare_uses_squared_and_absolute_errors():
    act = lav()[132:144]
    f = fc()
    e = f - act[:, None]
    for tr in (1, 2):
        r = tsx.fcompare(lav(), f, trunc=tr)
        assert list(dict.fromkeys(r.table["loss"])) == ["mse", "mae"]
        assert r.table.equals(tsx_compare_losses({"mse": e ** 2, "mae": np.abs(e)}, tr, 12))
        # Diebold-Mariano computed directly
        d = e[:, 0] ** 2 - e[:, 1] ** 2
        dc = d - d.mean()
        lrv = np.var(dc, ddof=1) + 2 * sum(np.sum(dc[k:] * dc[:12 - k])
                                            for k in range(1, tr + 1)) / 12
        dm = d.mean() / np.sqrt(lrv / 12)
        row = r.table[(r.table["f1"] == 1) & (r.table["f2"] == 2) & (r.table["loss"] == "mse")]
        expect_equal(row["dm"].iloc[0], dm)
        expect_equal(row["p_dm"].iloc[0], 2 * stats.norm.cdf(-abs(dm)))
    # Wilcoxon (exact, no ties) and sign test computed directly
    row = r.table[(r.table["f1"] == 1) & (r.table["f2"] == 3) & (r.table["loss"] == "mae")]
    w = stats.wilcoxon(np.abs(e[:, 0]), np.abs(e[:, 2]), method="exact")
    d = np.abs(e[:, 0]) - np.abs(e[:, 2])
    ranks = stats.rankdata(np.abs(d))
    assert row["wilcoxon"].iloc[0] == np.sum(ranks[d > 0])
    expect_equal(row["p_wilcoxon"].iloc[0], w.pvalue)
    n1 = np.sum(np.abs(e[:, 0]) > np.abs(e[:, 2]))
    expect_equal(row["sign"].iloc[0], (n1 - 6) / (0.5 * np.sqrt(12)))


def test_bias_mae_rmse_and_interval_measures_agree_with_direct_computations():
    y = lav()
    f = fc()
    act = y[132:144]
    # standard deviations of the three forecasts (growing with the horizon)
    st = np.outer(np.sqrt(np.arange(1, 13)), [0.025, 0.04, 0.015])
    for lv in (0.95, 0.8):
        r = tsx.faccuracy(y, f, st, level=lv)
        al = 1 - lv
        z = stats.norm.ppf(1 - al / 2)
        for k in range(3):
            e = f[:, k] - act
            lo = f[:, k] - z * st[:, k]
            up = f[:, k] + z * st[:, k]
            tab = r.table.iloc[k]
            expect_equal(tab["rmse"], np.sqrt(np.mean(e ** 2)))
            expect_equal(tab["bias_mae"], abs(np.mean(e)) + np.mean(np.abs(e)))
            expect_equal(tab["coverage"], np.mean((act >= lo) & (act <= up)))
            expect_equal(tab["range"], np.mean(up - lo))
            mis = np.mean((up - lo) + 2 / al * np.maximum(lo - act, 0)
                          + 2 / al * np.maximum(act - up, 0))
            expect_equal(tab["mis"], mis)

            def pin(q, tau):
                return np.mean(np.where(act >= q, tau * (act - q), (1 - tau) * (q - act)))

            expect_equal(tab["pinball_lower"], pin(lo, al / 2))
            expect_equal(tab["pinball_upper"], pin(up, 1 - al / 2))
            h = r.by_horizon[r.by_horizon["forecast"] == k + 1].reset_index(drop=True)
            expect_equal(h["rmse"][11], tab["rmse"])
            expect_equal(h["bias_mae"][11], tab["bias_mae"])
            expect_equal(h["bias_mae"][2], abs(np.mean(e[:3])) + np.mean(np.abs(e[:3])))
            expect_equal(h["mis"][11], tab["mis"])
            expect_equal(h["coverage"][2], np.mean((act[:3] >= lo[:3]) & (act[:3] <= up[:3])))
    # without intervals the interval measures are nan
    r = tsx.faccuracy(y, f)
    assert r.table[["coverage", "range", "mis", "pinball_lower", "pinball_upper"]].isna().all().all()
    assert list(r.table.columns[1:5]) == ["n", "bias", "mae", "bias_mae"]
    with pytest.raises(ValueError, match="between 0 and 1"):
        tsx.faccuracy(y, f, st, level=95)
    # standard deviations of the first forecast only: no interval measures
    # for the others
    r1 = tsx.faccuracy(y, f, st[:, 0])
    assert r1.table["mis"][0] == tsx.faccuracy(y, f, st).table["mis"][0]
    assert r1.table["mis"][1:].isna().all()
    # wrong standard deviations
    with pytest.raises(ValueError, match="at most as many columns"):
        tsx.faccuracy(y, f, np.hstack([st, st]))
    with pytest.raises(ValueError, match="non negative"):
        tsx.faccuracy(y, f, -st)


def test_bands_of_several_series_and_forecasts_are_py_pm_z_stdpy():
    # two series, two forecasts: columns (f1 s1, f1 s2, f2 s1, f2 s2)
    y = np.column_stack([np.arange(1, 21), np.arange(21, 41)]).astype(float)
    py = np.column_stack([np.arange(15, 21) + 0.5, np.arange(35, 41) - 0.5,
                          np.arange(15, 21) - 1.0, np.arange(35, 41) + 1.0])
    sd = np.column_stack([np.full(6, 0.1), np.full(6, 0.2), np.full(6, 0.3), np.full(6, 0.4)])
    z = stats.norm.ppf(0.95)
    p = tsx.fplot(y, py, sd, series=2, forecast="all", level=0.9)
    assert p.call["level"] == 0.9
    expect_equal(p.lower[14:20, :], py[:, [1, 3]] - z * sd[:, [1, 3]])
    expect_equal(p.upper[14:20, :], py[:, [1, 3]] + z * sd[:, [1, 3]])
    r = tsx.faccuracy(y, py, sd, series=1, level=0.9)
    expect_equal(r.table["range"], 2 * z * np.array([0.1, 0.3]))


def test_alignment_of_actual_values_and_forecasts():
    y = lav()
    f = fc()
    # forecasts shorter than the actual data: aligned at the end
    a = tsx.faccuracy(y, f)
    # actual data of the forecasting period only: origin 0, no MASE
    b = tsx.faccuracy(y[132:144], f)
    assert b.call["origin"] == 0
    assert b.table["mase"].isna().all()
    assert np.array_equal(a.table["mae"], b.table["mae"])
    # full length forecasts with explicit origin
    full = np.vstack([np.full((132, 3), np.nan), f])
    c1 = tsx.faccuracy(y, full, origin=132)
    assert c1.table.equals(a.table)


def test_fplot_returns_the_plotted_data():
    y = lav()
    f = fc()
    p = tsx.fplot(y, f[:, 0], np.full(12, 0.05))
    assert p.origin == 132
    assert p.lower.shape == (144, 1)
    expect_equal(p.upper[132:144, 0], f[:, 0] + stats.norm.ppf(0.975) * 0.05)
    expect_equal(p.errors[132:144, 0], f[:, 0] - y[132:144])
    p = tsx.fplot(y, f, forecast="all", subsample=12)
    assert list(p.time) == list(range(133, 145))
    assert p.forecasts.shape[1] == 3
    assert p.forecast_names == ["F1", "F2", "F3"]
    with pytest.raises(ValueError, match="forecast"):
        tsx.fplot(y, f, forecast=4)


def test_forecasts_without_overlap_with_the_actual_values():
    y = lav()
    f = fc()
    # forecasts of periods 145-156, actual values up to 144
    full = np.vstack([np.full((144, 3), np.nan), f])
    for o in (0, 144):
        p = tsx.fplot(y, full, origin=o, forecast="all")
        assert p["class"][0] == "tsx_fplot"
        assert len(p.actual) == 156
        with pytest.raises(tsx.TsxNoOverlapError):
            tsx.faccuracy(y, full, origin=o)
        with pytest.raises(tsx.TsxNoOverlapError):
            tsx.fcompare(y, full, origin=o)
    # partial overlap still gives tables
    part = np.vstack([np.full((138, 3), np.nan), f])
    assert list(tsx.faccuracy(y, part, origin=138).table["n"]) == [6, 6, 6]


def _per(x, start):
    x = np.asarray(x)
    idx = pd.period_range(start, periods=x.shape[0], freq="M")
    return pd.DataFrame(x, index=idx) if x.ndim == 2 else pd.Series(x, index=idx)


def test_period_inputs_are_aligned_by_their_dates():
    y = data("la")                                     # 1949-1960, monthly
    f = fc()                                           # forecasts of 1960
    # forecasts of 1960 with a PeriodIndex: same result as the positional alignment
    f60 = _per(f, "1960-01")
    assert tsx.faccuracy(y, f60).table.equals(tsx.faccuracy(lav(), f).table)
    assert tsx.fcompare(y, f60).table.equals(tsx.fcompare(lav(), f).table)
    # forecasts of 1961: after the end of the data, no overlap
    f61 = _per(f, "1961-01")
    p = tsx.fplot(y, f61, forecast="all")
    assert p.origin == 144
    assert len(p.actual) == 156
    assert np.isnan(p.actual[144:156]).all()
    assert np.array_equal(p.forecasts[144:156, :], f)
    assert list(p.dates[[0, 155]]) == list(pd.to_datetime(["1949-01-01", "1961-12-01"]))
    with pytest.raises(tsx.TsxNoOverlapError):
        tsx.faccuracy(y, f61)
    # forecasts of 1960-07 to 1961-06: partial overlap of 6 periods
    fmid = _per(f, "1960-07")
    r = tsx.faccuracy(y, fmid)
    assert r.call["origin"] == 138
    assert list(r.table["n"]) == [6, 6, 6]
    expect_equal(r.table["bias"], np.mean(f[:6, :] - lav()[138:144, None], axis=0))
    # forecasts starting before the data
    a = tsx_forecast_align(y, _per(f, "1948-01"))
    assert a["y"].shape[0] == 156
    assert a["origin"] == 0
    assert a["y"][12, 0] == lav()[0]
    # standard deviations: with a PeriodIndex or with the rows of py
    sd = 0.05 * np.sqrt(np.arange(1, 13))
    p1 = tsx.fplot(y, f61.iloc[:, 0], sd)
    p2 = tsx.fplot(y, f61.iloc[:, 0], _per(sd, "1961-01"))
    assert np.array_equal(p1.lower, p2.lower, equal_nan=True)
    expect_equal(p1.upper[144:156, 0], f[:, 0] + stats.norm.ppf(0.975) * sd)
    # errors
    with pytest.raises(ValueError, match="same frequency"):
        tsx.fplot(y, pd.DataFrame(f, index=pd.period_range("1961Q1", periods=12, freq="Q")))
    with pytest.raises(ValueError, match="same number of rows"):
        tsx.fplot(y, f61.iloc[:, 0], sd[:6])
    # inputs of different types
    with pytest.raises(ValueError, match="same type"):
        tsx.faccuracy(y, f61.to_numpy())


def test_forecast_functions_check_their_inputs():
    with pytest.raises(ValueError, match="multiple"):
        tsx.faccuracy(data("scc"), lav()[:12])
    with pytest.raises(ValueError, match="two forecasts"):
        tsx.fcompare(lav(), fc()[:, 0])
