# Short series, invalid inputs, one series against several and missing
# values.

import numpy as np
import pandas as pd
import pytest

import tsexplorer as tsx

from conftest import data, ref_input, values


def test_short_series_give_clear_errors():
    with pytest.raises(ValueError, match="Too few data points"):
        tsx.vident(np.arange(5.0))
    with pytest.raises(ValueError, match="Not enough data"):
        tsx.stdmean(np.arange(20.0), s=12)
    with pytest.raises(ValueError, match="Too few observations"):
        tsx.vtsay(np.random.default_rng(1).normal(size=12), 3)
    with pytest.raises(ValueError, match="Not enough data"):
        tsx.vdif(np.arange(5.0), 1, 12)
    with pytest.raises(ValueError, match="lags"):
        tsx.johansentest(data("airpas"), 1)


def test_invalid_options_give_clear_errors():
    airpas = data("airpas")
    with pytest.raises(ValueError, match="'s'"):
        tsx.plotband(airpas, s=0)
    with pytest.raises(ValueError, match="'bins'"):
        tsx.vhist(airpas, bins="a")
    with pytest.raises(ValueError, match="'group'"):
        tsx.vboxcox(airpas, group=1)
    with pytest.raises(ValueError, match="'maxdim'"):
        tsx.vbds(airpas, maxdim=1)
    with pytest.raises(ValueError, match="two series"):
        tsx.vscatter(airpas)
    with pytest.raises(ValueError, match="Give two series"):
        tsx.vscatter(data("scc"), series=1)
    with pytest.raises(ValueError, match="between 0 and 1"):
        tsx.fplot(np.arange(10.0), np.arange(3.0), level=1)


def test_one_series_of_several_gives_the_results_of_that_series():
    scc = data("scc")
    y2 = values(scc)[:, 1]
    for fun in (tsx.vident, tsx.nltests):
        a = fun(scc, 10, series=2)
        b = fun(y2, 10)
        assert a.table.equals(b.table)
        assert a.series == "y2"
    assert tsx.vcusum(scc, series="y2").table.equals(tsx.vcusum(y2).table)
    assert np.array_equal(tsx.vqqplot(scc, series=2).table, tsx.vqqplot(y2).table)
    g = tsx.gausstest(scc).table.iloc[[1]].reset_index(drop=True)
    g1 = tsx.gausstest(y2, names="y2").table
    assert g.equals(g1)


def test_missing_values_inside_the_sample():
    sn = ref_input("sim_na.csv")
    assert np.isnan(sn).any()
    # every tool runs with missing values (no nan in the main results)
    assert not tsx.vident(sn).table["acf"].isna().any()
    assert not tsx.varsbc(sn, 5).table["sbc"].isna().any()
    assert not tsx.vcumperiod(sn).table["cum_periodogram"].isna().any()
    assert not tsx.adftest(sn, 2).trend["t"].isna().any()
    st = tsx.sumstats(sn).stats
    assert st["missing"][0] == np.sum(np.isnan(sn))
    # rows with all the series missing at the ends are removed
    y = np.r_[np.nan, np.nan, values(data("airpas")).ravel(), np.nan]
    assert tsx.vident(y).table.equals(tsx.vident(data("airpas")).table)


def test_names_and_result_objects():
    r = tsx.vident(data("scc"), names=["A", "B", "C"], series="B")
    assert r.series == "B"
    assert r["class"] == ["tsx_vident", "tsx_result"]
    assert r.table is r["table"]
    assert "table" in dir(r)
    with pytest.raises(AttributeError):
        r.zz
    r2 = tsx.sumstats(pd.DataFrame({"x": [1.0, 2, 4], "y": [3.0, 1, 2]}))
    assert r2.series == ["x", "y"]
