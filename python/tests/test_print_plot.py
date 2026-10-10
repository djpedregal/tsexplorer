# Text output (TsxResult.text/print, the print() methods of R), plots
# (TsxResult.plot, matplotlib) and the windows of the results (show()).

import numpy as np
import pandas as pd
import pytest
from matplotlib.figure import Figure

import tsexplorer as tsx
from tsexplorer._utils_print import tsx_cat_block, tsx_format_table

from conftest import data, ref_input


def test_print_writes_the_lines_of_text(capsys):
    r = tsx.vident(data("dla"), ncoef=12)
    lines = r.text()
    assert isinstance(lines, list) and all(isinstance(s, str) for s in lines)
    assert any("Univariate Sample ACF and PACF" in s for s in lines)
    assert any("Ljung-Box" in s for s in lines)
    r.print()
    assert capsys.readouterr().out == "\n".join(lines) + "\n"
    assert repr(r) == "\n".join(lines)
    assert str(r) == repr(r)
    # 12 lags plus the header, notes and rules
    assert sum(s.strip()[:1].isdigit() for s in lines) == 12
    # the number of decimals can be changed
    assert any("%.2f" % r.table["acf"][0] in s for s in r.text(digits=2))


def test_text_of_every_class():
    scc = data("scc")
    lp = data("lydia_pinkham")
    dlp = tsx.vdif(np.log(lp))
    a = data("airpas")
    dla = data("dla")
    la = data("la")
    f = ref_input("sim_fc.csv")
    lav = data("lav")
    cases = [
        (tsx.sumstats(scc), ["Mode:", "Kurtosis (-3):", "Correlation Matrix:"]),
        (tsx.gausstest(scc), ["Bera-Jarque", "Multivariate Bera-Jarque"]),
        (tsx.vident2(dlp, ncoef=4), ["Partial Lag Autocorrelation", "k=4 AIC="]),
        (tsx.varsbc(dla, ncoef=8), ["SBC(", "P-CHI"]),
        (tsx.varsbc2(dla, ncoef=8), ["Minimum at lag"]),
        (tsx.vgranger(dlp, lags=[1, 2]), ["sales does not cause advertising"]),
        (tsx.vcusum(dla), ["CUSUM and CUSUMSQ"]),
        (tsx.stdmean(a), ["Least squares line"]),
        (tsx.testhet(a), ["Variance Ratio Tests", "Samples (1 - 48)"]),
        (tsx.vboxcox(a), ["Estimation of Box-Cox Lambdas:"]),
        (tsx.adftest(la, lags=[1, 2]), ["NO CONSTANT, NO TREND", "Phi3"]),
        (tsx.vphillips(la, lags=[1, 2]), ["Number of residual covs= "]),
        (tsx.johansentest(lp, lags=2), ["h= 0  -  h= 1", "Eigen1"]),
        (tsx.nltests(dla, ncoef=8), ["Peña & Rodriguez"]),
        (tsx.vtsay(dla, lags=3), ["Tsay-F", "z(t-1)*z(t-3)"]),
        (tsx.vbds(dla, maxdim=3), ["Distance as a fraction of the S.D.: 1.5"]),
        (tsx.vcumperiod(dla), ["Band half width"]),
        (tsx.vspectrum(dla, smooth=5), ["Triangular window (5)"]),
        (tsx.vspectrum(dlp, series=[1, 2]), ["Cross spectrum: advertising - sales"]),
        (tsx.varspectrum(dla, order=6), ["AR Spectrum(6)"]),
        (tsx.vboxplot(a), ["Box Plot (every 12 samples apart)", "1950-01"]),
        (tsx.vtboxplot(a), ["Transpose Box Plot"]),
        (tsx.vscatter(scc), ["Intercept"]),
        (tsx.vhist(dla), ["Histogram"]),
        (tsx.vqqplot(dla), ["QQ plot"]),
        (tsx.faccuracy(lav, f, 0.03 * np.ones((12, 3)), level=0.9),
         ["bias+mae:      |bias| + mae", "(nominal 0.9)", "pinball_upper"]),
        (tsx.fcompare(lav, f), ["Squared Errors (MSE)", "Absolute Errors (MAE)", "F#1 vs F#2:"]),
    ]
    for r, keys in cases:
        assert r.has_text()
        lines = r.text()
        for key in keys:
            assert any(key in s for s in lines), (r["class"][0], key)
    # without intervals the interval measures are not shown
    lines = tsx.faccuracy(lav, f).text()
    assert not any("coverage" in s or "mis:" in s for s in lines)
    assert any("rmse" in s for s in lines) and any("bias+mae" in s for s in lines)
    assert not any("Percentage" in s for s in lines)
    # dated forecasts: forecasting period
    d = pd.date_range("1949-01-01", periods=144, freq="MS")
    r = tsx.faccuracy(pd.DataFrame({"date": d, "y": lav}),
                      pd.DataFrame({"date": d[132:], "f1": f[:, 0], "f2": f[:, 1]}))
    assert any("Forecasting period: 1960-01 to 1960-12" in s for s in r.text())
    # results without a text method show their fields
    r = tsx.plotband(a)
    assert not r.has_text()
    assert r.text()[0] == "<tsx_plotband>"
    assert any(s.startswith(" $ data: ndarray [144x1]") for s in r.text())


def test_text_tables_are_aligned():
    lines = tsx_format_table([np.array([1, 22.5]), np.array(["a", "bcd"]),
                              np.array([np.nan, np.inf])], [0, 0, 2], ["r1", "row2"],
                             ["N", "S", "V"])
    # 22.5 with no decimals is 22, as in R (C's printf rounds half to even)
    assert lines == ["       N    S    V", "r1     1    a   NA", "row2  22  bcd  Inf"]
    block = tsx_cat_block("Title", "note", lines)
    assert len(block[0]) == 40
    assert block[1] == "Title"
    assert block[3] == "note"


def _titles(fig):
    return [ax.get_title() for ax in fig.axes] + [fig._suptitle.get_text()
                                                    if fig._suptitle else ""]


def test_plots_of_every_class():
    scc = data("scc")
    dlp = data("dlp")
    a = data("airpas")
    dla = data("dla")
    la = data("la")
    f = ref_input("sim_fc.csv")
    cases = [
        (tsx.plotband(a), 1, "2*S.D. bands"),
        (tsx.plotband(a, overlay=True), 1, "every 12 samples"),
        (tsx.plotband(scc, series="all", standard=True), 1, "Standardised Plot"),
        (tsx.vboxplot(a, highlight=2), 1, "Box Plot"),
        (tsx.vtboxplot(a), 1, "Transpose Box Plot"),
        (tsx.vscatter(scc), 1, "Scatter Plot: Series y1 vs y2"),
        (tsx.vscatter(scc, series="all"), 9, "Scatter Plots for All Series"),
        (tsx.vhist(dla), 1, "Histogram"),
        (tsx.vqqplot(dla), 1, "Empirical Quantiles"),
        (tsx.vident(dla), 2, "Univariate Sample Autocorrelation"),
        (tsx.varsbc(dla, ncoef=8), 2, "Information Criteria"),
        (tsx.varsbc2(dla, ncoef=8), 1, "SBC Criterion"),
        (tsx.vcusum(dla), 2, "CUSUMSQ"),
        (tsx.stdmean(a, type=1), 1, "MEDA - Median Plot"),
        (tsx.vboxcox(a), 1, "L-Lik"),
        (tsx.nltests(dla, ncoef=8), 2, "Squared Data"),
        (tsx.vcumperiod(dla), 1, "Cumulative Periodogram"),
        (tsx.vspectrum(dla, smooth=3), 1, "Smoothed Spectrum"),
        (tsx.vspectrum(dlp, series=[1, 2], smooth=3), 3, "Coherence"),
        (tsx.varspectrum(dla), 1, "AR Spectrum(16)"),
        (tsx.fplot(la, pd.DataFrame(f, index=pd.period_range("1960-01", periods=12, freq="M")),
                   0.03 * np.ones((12, 3)), forecast="all"), 2, "confidence bands"),
    ]
    for r, nax, title in cases:
        assert r.has_plot()
        fig = Figure()
        out = r.plot(fig=fig)
        assert out is fig
        assert len(fig.axes) == nax, r["class"][0]
        assert any(title in t for t in _titles(fig)), r["class"][0]
        # the figure is reused: its contents are replaced
        r.plot(fig=fig)
        assert len(fig.axes) == nax


def test_plot_of_vident2_and_classes_without_plot():
    r = tsx.vident2(data("dlp"), ncoef=6)
    fig = Figure()
    r.plot(fig=fig, series=[1, 2])
    assert any(t.startswith("CCF between advertising(t) and sales(t-k)") for t in _titles(fig))
    assert fig.axes[0].get_xlim()[0] < -7 < 7 < fig.axes[0].get_xlim()[1]
    r.plot(fig=fig, series="sales")
    assert any("Series sales" in t for t in _titles(fig))
    with pytest.raises(ValueError, match="series"):
        r.plot(fig=fig, series=3)
    with pytest.raises(ValueError, match="No plot available"):
        tsx.adftest(data("la"), lags=1).plot(fig=fig)
    # without a figure, a new pyplot figure
    import matplotlib.pyplot as plt
    out = tsx.vident(data("dla")).plot()
    assert out in [plt.figure(n) for n in plt.get_fignums()]
    plt.close("all")


def test_display_in_ipython_without_windows(capsys):
    from tsexplorer._windows import tsx_ipython_display
    old = tsx.options["window"]
    tsx.options["window"] = False
    try:
        r = tsx.gausstest(data("scc"))
        tsx_ipython_display(r)
        assert capsys.readouterr().out == "\n".join(r.text()) + "\n"
    finally:
        tsx.options["window"] = old


def _tk_available():
    import os
    if os.environ.get("TSX_NO_TK"):   # no usable display (e.g. macOS CI runners)
        return False
    try:
        import tkinter as tk
        root = tk.Tk()
        root.destroy()
        return True
    except Exception:
        return False


@pytest.mark.skipif(not _tk_available(), reason="no display for Tk")
def test_results_shown_go_to_the_text_and_graphics_windows():
    from tsexplorer import _windows as w

    def text(st):
        return st.text.get("1.0", "end")

    a = data("airpas")
    st = tsx.vident(a).show()
    try:
        assert "Univariate Sample ACF" in text(st)
        assert st.heading.cget("text") == "vident   [Series: #1]"
        assert len(st.figure.axes) == 2
        # a result without plot: text only, in the same window
        st2 = tsx.adftest(a, lags=2).print(window=True)
        assert st2 is None
        assert "Augmented Dickey-Fuller" in text(st)
        assert w.tsx_tk_main("tooltest") is st
        # a result with only a plot keeps the text
        tsx.plotband(a).show()
        assert "Augmented Dickey-Fuller" in text(st)
        assert len(st.figure.axes) == 1
        # forecast results go to the windows of toolforecast, not to tooltest
        y = data("lav")
        f = ref_input("sim_fc.csv")
        sf = tsx.faccuracy(y, f).show()
        assert sf is not st
        assert "Forecasting Results" in text(sf)
        assert sf.figure is None
        assert tsx.fplot(y, f, forecast="all").show() is sf
        assert len(sf.figure.axes) == 2
        assert "Univariate" not in text(st) and "Augmented" in text(st)
        # closing the graphics window: a new one is opened when needed
        st.close_graphics()
        tsx.vident(a).show()
        assert len(st.figure.axes) == 2
    finally:
        for k in list(w._WINDOWS):
            w._WINDOWS[k].close()
    assert w.tsx_tk_main("tooltest") is None
    assert w.tsx_tk_main("toolforecast") is None
