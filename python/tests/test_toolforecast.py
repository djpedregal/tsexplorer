# toolforecast: tables and texts of the interface (_gui_common.py) and the
# tkinter interface, driven through state.actions and its menus.

import numpy as np
import pandas as pd
import pytest
from scipy import stats

import tsexplorer as tsx
from tsexplorer import _windows
from tsexplorer._gui_common import tsx_fgui_tables, tsx_fgui_text
from tsexplorer._gui_tk import ToolforecastState, toolforecast_tk, tooltest_tk

from conftest import data, expect_equal, ref_input


def fc():
    return ref_input("sim_fc.csv")


def test_toolforecast_state_gives_the_results_of_the_core_functions():
    y = data("lav")
    f = fc()
    st = ToolforecastState(y, f)
    st.actions["set_forecast"]("all")
    st.actions["set_options"]({"s": "12", "trunc": "2"})
    assert st.result["class"][0] == "tsx_fplot"
    assert st.last_call["args"]["forecast"] == "all"
    assert st.tables["accuracy"].table.equals(tsx.faccuracy(y, f).table)
    assert st.tables["compare"].table.equals(tsx.fcompare(y, f, trunc=2).table)
    assert any("Diebold" in s for s in st.text())
    st.actions["set_forecast"](2)
    st.actions["set_nav"]("12")
    assert list(st.result.time) == list(range(133, 145))
    st.actions["prev"]()
    assert st.subsample == 11
    st.actions["nxt"]()
    st.actions["nxt"]()
    assert st.subsample == 12
    assert any("Forecast #2" in s for s in tsx_fgui_text(st.tables, st.forecast))
    with pytest.raises(ValueError, match="number"):
        st.actions["set_options"]({"s": "abc"})


def test_toolforecast_state_passes_the_intervals_and_the_level():
    y = data("lav")
    f = fc()
    sd = np.full(12, 0.03)
    s = ToolforecastState(y, f, sd, level=0.9)
    s.refresh()
    assert s.tables["accuracy"].table.equals(tsx.faccuracy(y, f, sd, level=0.9).table)
    expect_equal(s.result.upper[132:144, 0], f[:, 0] + stats.norm.ppf(0.95) * 0.03)
    s.actions["set_options"]({"level": "0.8"})
    assert s.tables["accuracy"]["call"]["level"] == 0.8
    # the plot uses the new level too
    expect_equal(s.result.upper[132:144, 0], f[:, 0] + stats.norm.ppf(0.9) * 0.03)
    with pytest.raises(ValueError, match="maximum"):
        s.actions["set_options"]({"level": "95"})


def test_toolforecast_without_overlap_shows_the_plot_and_the_forecasts():
    y = data("lav")
    f = fc()
    full = np.vstack([np.full((144, 3), np.nan), f])
    st = ToolforecastState(y, full, origin=144)
    for k in (1, 2, "all"):
        st.actions["set_forecast"](k)
        assert st.result["class"][0] == "tsx_fplot"
        assert st.tables["no_overlap"]
        assert any("forecasts only" in s for s in st.text())
    st.actions["set_nav"]("13")
    assert list(st.result.time) == list(range(145, 157))
    # table of the forecasts only (no actual values nor error measures)
    tabs = tsx_fgui_tables(y, full, None, 144, 1, 1, 0.95, None, 3)
    assert tabs["no_overlap"] and tabs["accuracy"] is None
    txt = tsx_fgui_text(tabs, "all")
    assert any("F#3" in s for s in txt)
    assert not any(k in s for s in txt for k in ("MAE", "Bias", "Coverage"))
    head = [s for s in txt if s.lstrip().startswith("t ")]
    assert len(head) == 1 and "actual" not in head[0]
    rows = [s for s in txt if s.strip()[:3].isdigit() and 145 <= int(s.split()[0]) <= 156]
    assert len(rows) == 12
    assert "%.3f" % f[0, 2] in rows[0]
    one = tsx_fgui_text(tabs, 2)
    assert any("Forecast #2" in s for s in one)
    assert not any("lower" in s for s in one)
    # with standard deviations: bounds of the intervals of one forecast
    sd = np.vstack([np.full((144, 3), np.nan), np.full((12, 3), 0.05)])
    tb = tsx_fgui_tables(y, full, sd, 144, 1, 1, 0.9, None, 3)
    one = tsx_fgui_text(tb, 1)
    assert any("90% prediction intervals" in s for s in one)
    r1 = [s for s in one if s.startswith("145 ")][0]
    assert "%.3f" % (f[0, 0] + stats.norm.ppf(0.95) * 0.05) in r1
    # partial overlap still gives tables
    part = np.vstack([np.full((138, 3), np.nan), f])
    assert not tsx_fgui_tables(y, part, None, 138, 1, 1, 0.95, None, 3)["no_overlap"]


def test_toolforecast_tables_show_the_dates():
    d = pd.date_range("1949-01-01", periods=144, freq="MS")
    f = fc()
    y = pd.DataFrame({"date": d, "y": data("lav")})
    py = pd.DataFrame({"date": d[132:], "f1": f[:, 0], "f2": f[:, 1], "f3": f[:, 2]})
    tabs = tsx_fgui_tables(y, py, None, 0, 1, 1, 0.95, None, 3)
    one = tsx_fgui_text(tabs, 1)
    assert any("date" in s for s in one)
    assert any("1960-03" in s for s in one)
    assert any("Forecasting period" in s for s in one)
    all_ = tsx_fgui_text(tabs, "all")
    assert sum("Forecasting period: 1960-01 to 1960-12" in s for s in all_) >= 2
    st = ToolforecastState(y, py)
    st.refresh()
    assert st.result.dates.equals(d)
    st.actions["set_forecast"]("all")
    assert not isinstance(st.result, Exception)
    # forecasts after the data
    dfut = pd.date_range("1961-01-01", periods=12, freq="MS")
    tabs = tsx_fgui_tables(pd.Series(data("lav"), index=d), pd.DataFrame(f, index=dfut), None,
                           0, 1, 1, 0.95, None, 3)
    txt = tsx_fgui_text(tabs, "all")
    assert any("Forecasting period: 1961-01" in s for s in txt)
    assert any("1961-12" in s for s in txt)
    # inputs of different types
    with pytest.raises(ValueError, match="same type"):
        tsx.toolforecast(y, f, wait=False)


def test_toolforecast_with_several_series():
    y = np.column_stack([np.arange(1, 21), np.arange(21, 41)]).astype(float)
    py = np.column_stack([np.arange(15, 21) + 0.5, np.arange(35, 41) - 0.5,
                          np.arange(15, 21) - 1.0, np.arange(35, 41) + 1.0])
    st = ToolforecastState(y, py, names="a b")
    st.refresh()
    assert st.tables["accuracy"].series == "a"
    st.actions["set_series"](2)
    assert st.tables["accuracy"].series == "b"
    assert st.result.series == "b"
    expect_equal(st.tables["accuracy"].table["bias"], [-0.5, 1.0])


def _tk_available():
    try:
        import tkinter as tk
        root = tk.Tk()
        root.destroy()
        return True
    except Exception:
        return False


needs_tk = pytest.mark.skipif(not _tk_available(), reason="no display for Tk")


def _text(st):
    return st.tk["text"].get("1.0", "end")


@needs_tk
def test_the_toolforecast_window_is_built_and_driven_by_its_menus():
    y = data("lav")
    f = fc()
    sf = toolforecast_tk(y, f)
    try:
        assert "Forecast #1" in _text(sf)
        assert sf.tk["title"].cget("text") == "Series: #1   Forecast: #1"
        assert len(sf.win.figure.axes) == 2
        fm = sf.tk["forecasts_menu"]
        assert [fm.entrycget(i, "label") for i in range(fm.index("end") + 1)
                if fm.type(i) == "command"] == ["#1", "#2", "#3", "All"]
        fm.invoke(fm.index("end"))
        assert sf.forecast == "all"
        assert "Diebold" in _text(sf)
        fm.invoke(1)
        assert sf.forecast == 2
        assert sf.tk["series_menu"] is None      # one series: no Series menu
        sf.tk["nav"]["nxt"].invoke()
        assert sf.subsample == 1 and sf.tk["nav"]["var"].get() == "1"
        dlg = sf.actions["options_dialog"]()
        assert dlg.winfo_exists()
        dlg.destroy()
        # its windows are shifted with respect to those of tooltest
        assert sf.win.top.winfo_y() >= 40
        # results of the forecasting tools shown at the console go to them
        tsx.faccuracy(y, f).show()
        assert "Forecasting Results" in _text(sf)
    finally:
        sf.actions["close"]()
    assert sf.tk is None and _windows.tsx_tk_main("toolforecast") is None


@needs_tk
def test_toolforecast_and_tooltest_have_their_own_windows():
    y = data("lav")
    f = fc()
    s3 = tooltest_tk(data("airpas"))
    w3 = s3.win
    f1 = toolforecast_tk(y, f)
    try:
        assert f1.win is not s3.win
        assert s3.tk is not None
        assert _windows.tsx_tk_main("tooltest") is s3.win
        assert _windows.tsx_tk_main("toolforecast") is f1.win
        top = f1.win.top
        f2 = tsx.toolforecast(y, f, wait=False)
        assert f2.win.top is top
        assert f1.tk is None
        assert "Forecast #1" in _text(f2)
        # and tooltest reuses its own windows, not those of toolforecast
        s4 = tooltest_tk(data("scc"))
        assert s4.win is w3
        assert s3.win is None
        assert f2.tk is not None
        f2.actions["close"]()
        assert _windows.tsx_tk_main("toolforecast") is None
        assert _windows.tsx_tk_main("tooltest") is s4.win
    finally:
        for k in list(_windows._WINDOWS):
            _windows._WINDOWS[k].close()
    assert _windows.tsx_tk_main("tooltest") is None
