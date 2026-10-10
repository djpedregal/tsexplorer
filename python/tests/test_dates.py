# Inputs with dates: PeriodIndex (ts of R), DatetimeIndex (zoo/xts of R) and
# DataFrame with a date column.

import numpy as np
import pandas as pd
import pytest
from scipy import stats

import tsexplorer as tsx

from conftest import data, expect_equal, ref_input, values


def dates_m():
    return pd.date_range("1949-01-01", periods=144, freq="MS")


def test_as_tsx_matrix_reads_the_dates_of_every_type_of_input():
    d = dates_m()
    x = values(data("airpas")).ravel()
    # PeriodIndex: first day of each period
    assert tsx.as_tsx_matrix(data("airpas"))[2].equals(d)
    q = pd.Series(np.arange(1, 9.0), index=pd.period_range("2000Q2", periods=8, freq="Q"))
    assert list(tsx.as_tsx_matrix(q)[2]) == list(pd.to_datetime(
        ["2000-04-01", "2000-07-01", "2000-10-01", "2001-01-01", "2001-04-01", "2001-07-01",
         "2001-10-01", "2002-01-01"]))
    a = pd.Series(np.arange(1, 6.0), index=pd.period_range("1990", periods=5, freq="Y"))
    assert list(tsx.as_tsx_matrix(a)[2]) == list(pd.to_datetime(
        ["%d-01-01" % k for k in range(1990, 1995)]))
    # DataFrame with a date column (anywhere) and without
    df = pd.DataFrame({"a": x, "date": d, "b": 2 * x})
    y, names, dates = tsx.as_tsx_matrix(df)
    assert names == ["a", "b"]
    assert dates.equals(d)
    assert tsx.as_tsx_matrix(pd.DataFrame({"a": x}))[2] is None
    # date-time
    tt = pd.date_range("2024-01-01", periods=10, freq="h", tz="UTC")
    assert tsx.as_tsx_matrix(pd.DataFrame({"t": tt, "v": np.arange(10)}))[2].equals(tt)
    # DatetimeIndex
    s = pd.DataFrame({"a": x, "b": 2 * x}, index=d)
    y, names, dates = tsx.as_tsx_matrix(s)
    assert names == ["a", "b"]
    assert dates.equals(d)
    assert np.array_equal(tsx.as_tsx_matrix(pd.Series(x, index=d))[0].ravel(), x)
    # trimming of missing values at the ends trims the dates
    df2 = pd.DataFrame({"date": d[:6], "v": [np.nan, np.nan, 1, 2, 3, np.nan]})
    y2, _, d2 = tsx.as_tsx_matrix(df2)
    assert d2.equals(d[2:5])
    assert list(y2.ravel()) == [1, 2, 3]
    # errors
    with pytest.raises(ValueError, match="more than one date"):
        tsx.as_tsx_matrix(pd.DataFrame({"d1": d, "d2": d, "v": x}))
    with pytest.raises(ValueError, match="increasing"):
        tsx.as_tsx_matrix(pd.DataFrame({"date": d[::-1], "v": x}))
    with pytest.raises(ValueError, match="numeric"):
        tsx.as_tsx_matrix(pd.DataFrame({"date": d, "v": x, "s": "a"}))


def test_the_results_do_not_depend_on_the_type_of_input():
    d = dates_m()
    x = values(data("airpas")).ravel()
    assert tsx.vident(pd.Series(x, index=d)).table.equals(tsx.vident(x).table)
    a1 = tsx.adftest(pd.Series(x, index=d), lags=[1, 2])
    a2 = tsx.adftest(x, lags=[1, 2])
    for k in ("none", "const", "trend"):
        assert a1[k].equals(a2[k])


def test_time_plots_keep_the_dates_of_the_data():
    d = dates_m()
    x = values(data("airpas")).ravel()
    df = pd.DataFrame({"date": d, "y": x})
    assert tsx.plotband(df).dates.equals(d)
    assert tsx.plotband(df, subsample=2).dates.equals(d[12:24])
    assert tsx.plotband(df, overlay=True).dates is None
    assert tsx.plotband(x).dates is None
    assert tsx.vcusum(df).dates.equals(d)
    assert tsx.vboxplot(df).group_dates.equals(d[::12])
    assert tsx.vboxplot(x).group_dates is None


def test_forecasts_with_dates_same_type_required_and_alignment_by_dates():
    d = dates_m()
    y = np.log(values(data("airpas")).ravel())
    f = ref_input("sim_fc.csv")
    fcols = {"f1": f[:, 0], "f2": f[:, 1], "f3": f[:, 2]}
    dfut = pd.date_range("1961-01-01", periods=12, freq="MS")
    d60 = d[132:144]
    # DataFrame with a date column
    ydf = pd.DataFrame({"date": d, "y": y})
    r = tsx.faccuracy(ydf, pd.DataFrame({"date": d60, **fcols}))
    assert r.table.equals(tsx.faccuracy(y, f).table)
    assert r.dates.equals(d60)
    assert list(r.by_horizon["date"][:12]) == list(d60)
    cmp = tsx.fcompare(ydf, pd.DataFrame({"date": d60, **fcols}))
    assert cmp.table.equals(tsx.fcompare(y, f).table)
    # DatetimeIndex, partial overlap (1960-07 to 1961-06)
    dmid = pd.date_range("1960-07-01", periods=12, freq="MS")
    rz = tsx.faccuracy(pd.Series(y, index=d), pd.DataFrame(f, index=dmid))
    assert rz.call["origin"] == 138
    assert list(rz.table["n"]) == [6, 6, 6]
    # forecasts after the data: plot data with dates, no tables
    p = tsx.fplot(pd.Series(y, index=d), pd.DataFrame(f, index=dfut), forecast="all")
    assert p.origin == 144
    assert p.dates.equals(d.append(dfut))
    with pytest.raises(tsx.TsxNoOverlapError):
        tsx.faccuracy(pd.Series(y, index=d), pd.DataFrame(f, index=dfut))
    tsx.fplot(pd.Series(y, index=d), pd.DataFrame(f, index=dfut), forecast=2, subsample=13)
    # standard deviations: same type as the forecasts or without dates
    sd = 0.05 * np.sqrt(np.arange(1, 13))
    b1 = tsx.fplot(ydf, pd.DataFrame({"date": d60, "f1": f[:, 0]}), sd)
    b2 = tsx.fplot(ydf, pd.DataFrame({"date": d60, "f1": f[:, 0]}),
                   pd.DataFrame({"date": d60, "sd": sd}))
    assert np.array_equal(b1.lower, b2.lower, equal_nan=True)
    expect_equal(b1.upper[132:144, 0], f[:, 0] + stats.norm.ppf(0.975) * sd)
    # different types
    with pytest.raises(ValueError, match="same type"):
        tsx.faccuracy(ydf, f)
    with pytest.raises(ValueError, match="same type"):
        tsx.faccuracy(y, pd.DataFrame({"date": d60, **fcols}))
    with pytest.raises(ValueError, match="same type"):
        tsx.faccuracy(pd.Series(y, index=d), pd.DataFrame({"date": d60, **fcols}))
    with pytest.raises(ValueError, match="same type"):
        tsx.faccuracy(np.log(data("airpas")), pd.DataFrame(f, index=d60))
    with pytest.raises(ValueError, match="same type as 'py'"):
        tsx.fplot(ydf, pd.DataFrame({"date": d60, "f1": f[:, 0]}), pd.Series(sd, index=d60))
    # different kinds of dates (with and without time zone)
    with pytest.raises(ValueError, match="different kinds"):
        tsx.faccuracy(ydf, pd.DataFrame({"date": d60.tz_localize("UTC"), **fcols}))
