# tooltest: the logic shared by the interfaces (_gui_common.py) and the
# tkinter interface. The interface keeps its state in an object and the
# widgets only call state.actions; the tests drive the interface through
# them (and through its menus when Tk has a display).

import numpy as np
import pandas as pd
import pytest

import tsexplorer as tsx
from tsexplorer import _windows
from tsexplorer._gui_common import (tsx_format_numbers, tsx_gui_option_text,
                                    tsx_gui_parse_option, tsx_gui_series, tsx_gui_set_option,
                                    tsx_gui_text, tsx_parse_numbers, tsx_tools, tsx_tools_for)
from tsexplorer._gui_tk import TooltestState, tooltest_tk

from conftest import data


def test_parse_numbers_reads_numeric_vectors_without_evaluating_code():
    p = tsx_parse_numbers
    assert p("1:4") == [1, 2, 3, 4]
    assert p("1 2 12") == [1, 2, 12]
    assert p("c(1, 3)") == [1, 3]
    assert np.allclose(p("[-1 : 0.5 : 1]"), [-1, -0.5, 0, 0.5, 1])
    assert p("4:1") == [4, 3, 2, 1]
    assert p("1 30; 50 90", matrix=True) == [[1, 30], [50, 90]]
    assert p("1 30; 50 90") == [1, 30, 50, 90]
    assert p("") is None
    with pytest.raises(ValueError, match="Invalid number"):
        p("system('ls')")
    with pytest.raises(ValueError):
        p("1:-1:5")


def test_format_numbers_is_the_inverse_of_parse_numbers():
    f = tsx_format_numbers
    assert f([1, 2, 3, 4]) == "1:4"
    assert f([1, 2, 12]) == "1 2 12"
    assert f(np.linspace(-1, 1, 21)) == "-1:0.1:1"
    assert f([[1, 30], [50, 90]]) == "1 30; 50 90"
    assert f(None) == ""
    for txt in ("1:4", "1 2 12", "-1:0.1:1", "1 30; 50 90"):
        assert f(tsx_parse_numbers(txt, matrix=True)) == txt


def test_options_typed_in_the_interface():
    tools = tsx_tools()
    ncoef = tools["vident"]["options"][0]
    assert tsx_gui_parse_option(ncoef, "10") == 10
    assert tsx_gui_parse_option(ncoef, 9.6) == 10
    with pytest.raises(ValueError, match="a number is expected"):
        tsx_gui_parse_option(ncoef, "abc")
    with pytest.raises(ValueError, match="the minimum is 4"):
        tsx_gui_parse_option(ncoef, "2")
    dist = tools["vbds"]["options"][1]
    assert tsx_gui_parse_option(dist, "1.25") == 1.25
    assert tsx_gui_parse_option(tools["plotband"]["options"][1], "TRUE") is True
    assert tsx_gui_parse_option(tools["vspectrum"]["options"][1], [True, False]) == [True, False]
    assert tsx_gui_parse_option(tools["stdmean"]["options"][1], "2") == 2
    assert tsx_gui_parse_option(tools["vgranger"]["options"][0], "1:3") == [1, 2, 3]
    assert tsx_gui_parse_option(tools["vgranger"]["options"][1], " ") is None
    assert tsx_gui_parse_option(tools["vboxcox"]["options"][1], "") is None
    assert tsx_gui_parse_option(tools["testhet"]["options"][0], "1 30; 50 90") == [[1, 30],
                                                                                   [50, 90]]
    assert tsx_gui_option_text(tools["adftest"]["options"][0], list(range(1, 13))) == "1:12"
    assert tsx_gui_option_text(ncoef, 38) == "38"
    assert tsx_gui_option_text(dist, 1.5) == "1.5"


def test_linked_options_and_series_selection():
    opts = tsx.tooltest_defaults(data("airpas"))
    new = tsx_gui_set_option(opts, "vident", "s", 4)
    assert [new[t]["s"] for t in ("plotband", "vboxplot", "vtboxplot", "vident2", "stdmean")] \
        == [4] * 5
    assert new["vboxcox"]["group"] == 4
    assert opts["plotband"]["s"] == 12
    new = tsx_gui_set_option(opts, "johansentest", "lags", [2, 3])
    assert new["adftest"]["lags"] == [2, 3] and new["vphillips"]["lags"] == [2, 3]
    assert tsx_gui_series("none") is None
    assert tsx_gui_series("single", 2) == 2
    assert tsx_gui_series("single_all", 2, all=True) == "all"
    assert tsx_gui_series("pair", 1, 1) == 1
    assert tsx_gui_series("pair", 1, 3) == [1, 3]
    assert tsx_gui_series("pair_all", 1) == [1, 2]
    assert tsx_gui_series("var", 1, all=True) == "all"
    # tools needing several series are not in the menu with one series
    assert "vident2" not in tsx_tools_for(1) and "vident2" in tsx_tools_for(2)


def test_tooltest_state_gives_the_calls_of_the_core_functions():
    scc = data("scc")
    st = TooltestState(scc)
    y = st.y
    opts = st.opts
    st.actions["set_tool"]("vident")
    st.actions["set_series"](2)
    assert st.result["class"][0] == "tsx_vident"
    assert st.last_call["args"]["series"] == 2
    assert st.result.table.equals(tsx.vident(y, ncoef=opts["vident"]["ncoef"], s=12, npar=0,
                                             series=2).table)
    # options with linked seasonal period
    st.actions["set_options"]({"ncoef": "10", "s": "4", "npar": "1"})
    assert st.result["call"]["ncoef"] == 10
    assert st.opts["plotband"]["s"] == 4
    with pytest.raises(ValueError, match="number"):
        st.actions["set_options"]({"ncoef": "abc"})
    # navigation
    st.actions["set_tool"]("plotband")
    st.actions["nxt"]()
    st.actions["nxt"]()
    assert list(st.result.time) == [5, 6, 7, 8]
    st.actions["prev"]()
    assert st.subsample == 1
    st.actions["set_nav"]("100")
    assert st.subsample == int(np.ceil(62 / 4))
    st.actions["set_nav"]("abc")
    assert st.subsample == 0
    st.actions["set_check"](True)
    assert st.result.data.shape == (4, 16)
    st.actions["set_series"](1, all=True)
    assert st.last_call["args"]["series"] == "all"
    st.actions["set_tool"]("vboxplot")
    st.actions["set_nav"]("3")
    assert st.result["call"]["highlight"] == 3
    # pair selection and text options
    st.actions["set_tool"]("vident2")
    st.actions["set_series"](1, 3)
    assert st.result["class"][0] == "tsx_vident2"
    assert st.series() == [1, 3]
    st.actions["set_tool"]("vgranger")
    st.actions["set_options"]({"lags": "1:2", "tests": "a-b"})
    assert list(st.result.table["test"]) == ["a-b"]
    assert st.last_call["args"]["lags"] == [1, 2]
    with pytest.raises(ValueError, match="Unknown tool"):
        st.actions["set_tool"]("foo")
    # errors of the core are shown as text
    st.actions["set_tool"]("vtsay")
    st.actions["set_options"]({"lags": "40"})
    assert isinstance(st.result, Exception)
    assert tsx_gui_text(st.result)[0].startswith("Error:")
    # errors of the plots are shown in the figure
    st.actions["set_tool"]("vboxcox")
    st.actions["set_options"]({"axislambdas": ""})
    assert st.result.grid is None
    assert "No grid of lambdas" in st.figure._suptitle.get_text()


def test_every_tool_runs_in_the_tooltest_state():
    for y in (data("dla"), data("dlp")):
        st = TooltestState(y)
        for tool in st.tools:
            st.actions["set_tool"](tool)
            assert not isinstance(st.result, Exception), (tool, st.result)
            assert st.result["class"][0] == "tsx_" + tool
            assert len(tsx_gui_text(st.result)) > 0
            if st.spec()["plot"]:
                assert len(st.figure.axes) > 0, tool
        if st.y.shape[1] == 1:
            assert "vident2" not in st.tools


def test_tooltest_runs_every_tool_with_dated_data():
    d = pd.date_range("1949-01-01", periods=144, freq="MS")
    a = data("airpas").to_numpy()
    st = TooltestState(pd.DataFrame({"date": d, "a": np.log(a), "b": a}))
    for tool in st.tools:
        st.actions["set_tool"](tool)
        assert not isinstance(st.result, Exception), tool
    st.actions["set_tool"]("plotband")
    assert st.result.dates.equals(d)
    # options given to tooltest() (see tooltest_defaults())
    opts = tsx.tooltest_defaults(st.y, vident={"ncoef": 12}, varspectrum=[8])
    st = TooltestState(st.y, opts)
    st.actions["set_tool"]("vident")
    assert st.result["call"]["ncoef"] == 12
    st.actions["set_tool"]("varspectrum")
    assert st.result["call"]["order"] == 8


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
def test_the_tooltest_window_is_built_and_driven_by_its_menus():
    y = data("scc")
    st = tooltest_tk(y)
    try:
        assert st.tool == "plotband"
        # the graphics window goes to the right of the text window
        top = st.win.top
        gw, gh, gx, gy = st.win.gpos
        assert gx > top.winfo_x() + top.winfo_width()
        assert st.win.gtop is not None and len(st.win.figure.axes) == 1
        st.actions["set_tool"]("adftest")
        assert "Augmented Dickey-Fuller" in _text(st)
        # the entries of the Tests menu select their tool (invoking the menu)
        tm = st.tk["tests_menu"]
        entries = {tm.entrycget(i, "label"): i for i in range(tm.index("end") + 1)
                   if tm.type(i) == "command"}
        assert list(entries)[0] == "Plot" and len(entries) == len(st.tools)
        assert sum(tm.type(i) == "separator" for i in range(tm.index("end") + 1)) == 6
        tm.invoke(entries["Univariate ACF and PACF"])
        assert st.tool == "vident"
        assert "Ljung-Box" in _text(st)
        assert st.tk["title"].cget("text") == "Univariate ACF and PACF   [Series: y1]"
        # the entries of the Series menu select their own series
        sm = st.tk["series_menu"]
        assert sm.index("end") == 2
        sm.invoke(0)
        assert st.series() == 1
        sm.invoke(1)
        assert st.series() == 2
        st.actions["set_tool"]("vident2")
        sub = sm.nametowidget(sm.entrycget(0, "menu"))
        sub.invoke(1)
        assert st.series() == [1, 2]
        assert st.result.series == ["y1", "y2", "y3"]
        sub.invoke(2)
        assert st.series() == [1, 3]
        sub2 = sm.nametowidget(sm.entrycget(1, "menu"))
        sub2.invoke(0)
        assert st.series() == 2
        # navigation widgets
        st.actions["set_tool"]("plotband")
        nav = st.tk["nav"]
        nav["nxt"].invoke()
        assert st.subsample == 1 and nav["var"].get() == "1"
        nav["var"].set("3")
        nav["entry"].focus_force()
        st.win.root.update()
        nav["entry"].event_generate("<Return>", when="now")
        st.win.root.update()
        assert st.subsample == 3
        assert nav["check"].instate(["!disabled"])
        st.actions["set_tool"]("vident")
        assert nav["prev"].instate(["disabled"])
        # options dialog
        dlg = st.actions["options_dialog"]()
        assert dlg is not None and dlg.winfo_exists()
        dlg.destroy()
        # results shown at the console go to the text window of the interface
        tsx.sumstats(data("airpas")).show()
        assert "Data points" in _text(st)
    finally:
        st.actions["close"]()
    assert st.tk is None and st.win is None
    assert _windows.tsx_tk_main("tooltest") is None


@needs_tk
def test_a_new_call_reuses_the_open_windows():
    y1 = data("airpas")
    y2 = data("scc")
    s1 = tooltest_tk(y1)
    top = s1.win.top
    s2 = tooltest_tk(y2)
    try:
        # same window, now with the new data; the old state no longer owns it
        assert s2.win.top is top
        assert s1.tk is None and s1.win is None
        assert _windows.tsx_tk_main("tooltest") is s2.win
        s2.actions["set_tool"]("vident")
        assert s2.tk["series_menu"].index("end") == 2
        # the output of the forecasting tools goes to other windows
        f = tsx.faccuracy(data("lav"), np.full(12, 6.0)).show()
        assert f is not s2.win
        assert "Ljung-Box" in _text(s2)
        f.close()
    finally:
        s2.actions["close"]()
    assert _windows.tsx_tk_main("tooltest") is None
    # after closing it, the next call opens a new window
    s3 = tsx.tooltest(y1, wait=False)
    try:
        assert s3.win.top is not top
        assert s3.result["class"][0] == "tsx_plotband"
    finally:
        s3.actions["close"]()
