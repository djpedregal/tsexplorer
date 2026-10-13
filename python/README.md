# tsexplorer for Python <img src="https://raw.githubusercontent.com/djpedregal/tsexplorer/main/r/man/figures/logo.png" align="right" height="139" alt="tsexplorer logo" />

Diego J. Pedregal (Universidad de Castilla-La Mancha). License GPL-3.

Exploratory, descriptive and diagnostic tools for univariate and
multivariate time series, and tools to evaluate and compare forecasts. Every
tool is a pure function returning a result with text output and a plot; the
graphical interfaces `tooltest` and `toolforecast` (tkinter) give
interactive access to all of them.

Contents: the 26 tools of the menu *Tests* of `tooltest`, the forecast
tools `faccuracy`, `fcompare` and `fplot`, the utilities
`tooltest_defaults`, `as_tsx_matrix`, `vdif`, `meda` and `adfcritical`,
and the example datasets (`load_data`).

Requirements: Python >= 3.10, numpy, scipy, pandas and matplotlib (tkinter,
included in the usual distributions of Python, for the windows and the
interfaces).

## Installation

From GitHub:

```sh
pip install "git+https://github.com/djpedregal/tsexplorer.git#subdirectory=python"
```

From a copy of the source code, in this folder: `pip install .`

## Use

```python
import numpy as np
import tsexplorer as tsx

airpas = tsx.load_data("airpas")          # pandas Series with a PeriodIndex
r = tsx.vident(np.log(airpas), ncoef=24, npar=2)
r.table                                   # lag, acf, se_acf, q_lb, p_lb, ...
a = tsx.adftest(np.log(airpas), lags=[1, 2, 3, 4])
a.trend
r                                         # text output
lines = a.text(digits=3)                  # the lines, without writing them
r.plot()                                  # plot in a new matplotlib figure
r.plot(fig=fig)                           # ... or in a given figure
r.show()                                  # text window + graphics window
```

`text()` gives the lines of the text output of a result, and
`repr()`/`print()` write them; `plot()` draws the plot with matplotlib in
the figure given (replacing its contents) or in a new `pyplot` figure. Each
class has its methods `tsx_text_<class>` and `tsx_plot_<class>`
(registered with `text_method()`/`plot_method()`), next to the function in
its module.

`show()` (or `print(window=True)`) sends the text to a text window and the
plot to a graphics window (tkinter, with the matplotlib figure embedded):
the windows of `tooltest` for its tools and those of `toolforecast` for
`faccuracy`, `fcompare` and `fplot`, independent and reused by new calls.
In an IPython console a result displayed at the prompt goes to these
windows (and the event loop of Tk is enabled, `%gui tk`); in a Jupyter
notebook the text and the plot are shown in the notebook;
`tsx.options["window"] = False` keeps the text at the console. The plain
Python console shows the text (`repr()`); in a script, `tsx.mainloop()`
keeps the windows open until they are closed.

## tooltest

```python
scc = tsx.load_data("scc")
app = tsx.tooltest(scc)
tsx.tooltest(scc, vident={"ncoef": 12, "s": 4}, varspectrum=[16])
```

A window with the menus *Tests* (the tools, in groups), *Series* and
*Options...*, the navigation `<<< value >>>` (subsamples of `plotband`,
highlighted group of the box plots) and the text output, with the plots in
a graphics window (matplotlib) to its right, without overlapping. There is
one text window and one graphics window of `tooltest`: a new call reuses
them and brings them to the front; closing the text window closes both; the
results shown with `show()` while it is open go to them. In a script
`tooltest()` waits until the window is closed (`wait=True`); in an
interactive session it returns at once.

The widgets only call the actions of the interface, which call the
functions of the package; `app = tooltest(...)` returns the state
(`app.tool`, `app.opts`, `app.last_call`, `app.result`) with its actions
(`app.actions["set_tool"]("vident")`, `set_series`, `prev`, `nxt`,
`set_nav`, `set_check`, `set_options`, `options_dialog`, `close`), and the
tests drive the interface through them and through its menus. The logic
shared with `toolforecast` (registry of tools, parsing of the options,
linked options, tables of the forecasts) is in `_gui_common.py` and the
windows in `_gui_tk.py`.

## toolforecast

```python
import pandas as pd
y = np.log(tsx.load_data("airpas").to_numpy())
py = np.column_stack([y[120:132], np.repeat(y[131], 12)])
tsx.toolforecast(y, py)
tsx.toolforecast(y, py, stdpy=np.repeat(0.05, 12), level=0.9)
d = pd.date_range("1949-01-01", periods=144, freq="MS")
tsx.toolforecast(pd.Series(y, index=d), pd.DataFrame(py, index=d[132:]))
```

A window with the menus *Series* (with several series), *Forecasts* (`#1`,
..., `#n`, *All*) and *Options...* (length of the subperiods, truncation
lag of the Diebold-Mariano test, confidence level of the intervals), the
navigation `<<< subperiod >>>` (0 = full sample) and the tables of
`faccuracy` (measures accumulated by horizon for one forecast, summary
table and `fcompare` tests for *All*; only the forecasts, and the bounds
of their intervals, when they do not overlap the actual values), with the
plot of `fplot` in a graphics window to its right. Its windows are
independent of those of `tooltest` (shifted down and right) and are reused
by a new call. `app = toolforecast(...)` returns the state (`s1`,
`forecast`, `s`, `subsample`, `trunc`, `level`, `last_call`, `result`,
`tables`, `text()`) with its actions (`set_series`, `set_forecast`, `prev`,
`nxt`, `set_nav`, `set_options`, `options_dialog`, `close`).

## Data and results

| Object | Type |
|---|---|
| input data | `T x m` (time in rows, series in columns): `numpy` array, `Series`/`DataFrame` with a `PeriodIndex` or a `DatetimeIndex`, or `DataFrame` with one `datetime64` (or period) column; see `as_tsx_matrix()` |
| names of the series | column names (or `Series.name`) or `names=` (list or one string with blank-separated names); by default `"#1"`, `"#2"`, ... |
| result | `TsxResult`: a `dict` whose keys are also attributes (`r.table`); key `"class"` = `["tsx_<f>", "tsx_result"]` |
| tables | `pandas.DataFrame` |
| matrices, arrays | `numpy.ndarray` (`vident2` arrays are `m x m x (ncoef + 1)`, `[:, :, k]` is lag `k`) |
| named vectors (`best`, `coef`, `bands`, `lambdas`) | `dict` |
| missing values | `nan`; options not given, `None` |
| dates | third output of `y, names, dates = as_tsx_matrix(...)` (`DatetimeIndex` or `None`) |
| `vdif()` | `DataFrame` with the names of the series and without dates |
| `fplot()` forecasts | field `forecast_names` (`["F1", ...]`) |
| errors | `ValueError`; `TsxNoOverlapError` (subclass of `ValueError`) when the forecasts do not overlap the actual values |
| datasets | `load_data("airpas")`, ... (CSV files in `src/tsexplorer/data/csv`) |
| tables of critical values | `src/tsexplorer/data/tables/*.csv` |
| internal functions | `tsexplorer._<module>.tsx_*` |

Series, forecasts, subsamples, groups, positions and observations are
numbered from 1 (`series=1` is the first series, whose default name is
`"#1"`; `testhet` cut points and `fplot()` `time` are observation numbers).

The distribution functions are those of `scipy.stats`. The Nelder-Mead
optimizer, the kernel density estimate, the signed rank test, the
histogram, the percentiles, the periodogram and the interpolation of the
critical values of `adfcritical` are implemented in the package
(`tsx_fminsearch`, `tsx_ksdensity`, `tsx_signrank`, `tsx_hist`,
`tsx_prctile`, `tsx_mspectrum`, ...). The bootstrap of
`sumstats(gaussian=False)` uses a `numpy.random.Generator` (`seed=`).

## Documentation

Every exported function has its help (a numpydoc docstring) with title and
description, *Parameters*, *Returns*, *References*, *See Also* and
*Examples*: `help(tsx.vident)` (`tsx.vident?` in IPython). The help of
the package is `help(tsexplorer)` and that of the datasets
`help(tsx.load_data)`.

`tests/test_examples.py` checks that every help has its sections and
documents every argument, and that its examples run (and that the results
of the examples have text and plots).

## Tests

The tests are not part of the installed package: they run from a clone of
the [GitHub repository](https://github.com/djpedregal/tsexplorer), which
also holds the reference results they read. From the folder `python`:

```
pip install ".[test]"
python -m pytest
```

The tests (`tests/test_*.py`) compare the results with stored reference
results and with independent computations (mean relative difference
1e-6). The tests of the windows and the interfaces need a display (they are
skipped without one).
