# tsexplorer for MATLAB

Diego J. Pedregal (Universidad de Castilla-La Mancha). License GPL-3.

Exploratory, descriptive and diagnostic tools for univariate and
multivariate time series, and tools to evaluate and compare forecasts. Every
tool is a function returning a `struct` with the results, which
`tsexplorer.print` writes as text and `tsexplorer.plot` draws; the
graphical interfaces `tooltest` and `toolforecast` give interactive access
to all of them. No toolbox is needed.

Contents: the 26 tools of the menu *Tests* of `tooltest`, the forecast
tools `faccuracy`, `fcompare` and `tsexplorer.fplot`, the utilities
`tooltest_defaults`, `as_tsx_matrix`, `vdif`, `meda` and `adfcritical`,
and the example datasets (`load_data`).

The functions are called by their names (`vident(y)`, `tooltest(y)`, ...),
except `plot`, `print` and `fplot`, which exist in MATLAB: they are in the
package `+tsexplorer` (`tsexplorer.plot`, `tsexplorer.print`,
`tsexplorer.fplot`) so that they do not hide the functions of MATLAB. The
internal functions are in `+tsexplorer/+internal`.

`adftest` has the same name as a function of the Econometrics Toolbox:
with this folder added to the path with `addpath` (which puts it first),
`adftest` is the one of this package. Its computations are in
`tsexplorer.adftest` (the `adftest` of the folder calls it), and `tooltest`
calls it by that full name, so the interface runs this test even when the
other `adftest` comes first on the path. MATLAB looks first in the current
folder, so do not work in a folder that has other files with the names of
these functions.

## Installation

Download the [GitHub repository](https://github.com/djpedregal/tsexplorer)
([ZIP](https://github.com/djpedregal/tsexplorer/archive/refs/heads/main.zip))
or clone it (`git clone https://github.com/djpedregal/tsexplorer.git`), and
add this folder (`matlab-new`, not `+tsexplorer`) to the path:

```matlab
addpath('path/to/tsexplorer/matlab-new')
savepath   % optional: keep it in the path for future sessions
```

## Use

```matlab
[y, names] = load_data("airpas");
r = vident(log(y), ncoef = 24, npar = 2);
r.table                                     % lag, acf, se_acf, q_lb, p_lb, ...
a = adftest(log(y), lags = 1:4);
a.trend
tsexplorer.print(r)                         % tables
lines = tsexplorer.print(a, digits = 3);    % the lines, without writing them
tsexplorer.plot(r)                          % plot in the current figure
```

Options are name-value arguments (`vident(y, ncoef = 24, npar = 2)`).
`tsexplorer.print` writes the text output of a result; `tsexplorer.plot`
draws its plot with base MATLAB graphics in the current figure (light
theme), replacing its contents. Each class has its methods
`tsexplorer.internal.tsx_text_<class>` and
`tsexplorer.internal.tsx_plot_<class>`. Results displayed at the command
line are sent to separate text and graphics windows only by the
interfaces.

## tooltest

```matlab
[y, names] = load_data("scc");
tooltest(y, "names", names)
tooltest(y, "vident", struct('ncoef', 12, 's', 4), "varspectrum", {16})
```

A window (`uifigure`) with the menus *Tests* (the tools, in groups),
*Series* and *Options...*, the navigation `<<< value >>>` (subsamples of
`plotband`, highlighted group of the box plots) and the text output, with
the plots in a graphics window (`figure`) to its right, without
overlapping. There is one text window and one graphics window of
`tooltest`: a new call reuses them and brings them to the front; closing
the text window closes both. The widgets only call the actions of the
interface, which call the functions of the package; `app = tooltest(...)`
returns them (`app.actions.set_tool("vident")`, `app.state()`, ...) and the
tests drive the interface through them and through its menus. The logic
shared with `toolforecast` (registry of tools, parsing of the options,
linked options) is in `+internal/tsx_tools.m`, `tsx_gui_*.m` and
`tsx_ui_*.m`.

## toolforecast

```matlab
y = log(load_data("airpas"));
py = [y(121:132), repmat(y(132), 12, 1)];
toolforecast(y, py)
toolforecast(y, py, stdpy = repmat(0.05, 12, 1), level = 0.9)
d = datetime(1949, 1:144, 1)';
toolforecast(timetable(d, y), timetable(d(133:144), py))
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
by a new call. `app = toolforecast(...)` returns the actions
(`set_series`, `set_forecast`, `prev`, `nxt`, `set_nav`, `set_options`,
`options_dialog`, `close`) and `app.state()`. The shared logic is in
`+internal/tsx_fgui_*.m` and the window in
`+internal/tsx_ui_toolforecast.m`.

## Data and results

| Object | Type |
|---|---|
| input data | `T x m` (time in rows, series in columns): numeric matrix, `timetable`, or `table` with one `datetime` column; see `as_tsx_matrix` |
| names of the series | variable names of the table or `names =` (string array or one string with blank-separated names); by default `"#1"`, `"#2"`, ... |
| result | `struct` whose first field `class` is `["tsx_<f>" "tsx_result"]` |
| tables | `table` |
| named vectors (`best`, `coef`, `bands`) | `struct` |
| missing values | `NaN`; options not given, `[]` |
| dates | third output of `[y, names, dates] = as_tsx_matrix(...)` |
| errors | `error`; identifier `tsexplorer:no_overlap` when the forecasts do not overlap the actual values |
| datasets | `load_data("airpas")`, ... (CSV files in `data/csv`) |
| tables of critical values | `data/tables/*.csv` |
| internal functions | `tsexplorer.internal.tsx_*` |
| text output | `tsexplorer.print(x)`, `tsexplorer.print(x, digits = 3)`; `lines = tsexplorer.print(x)` returns the lines without writing them |
| plots | `tsexplorer.plot(x)`, `tsexplorer.plot(x, series = [1 2])` (`vident2`) |

Series, forecasts, subsamples, groups, positions and observations are
numbered from 1.

No toolbox is needed: the distribution functions (`tsx_pchisq`, `tsx_pf`,
`tsx_pt`, `tsx_pgamma`, `tsx_pnorm`, `tsx_qnorm`) use `gammainc`, `betainc`
and `erfc`, and the Nelder-Mead optimizer, the kernel density estimate,
the signed rank test, the histogram and the percentiles are implemented in
the package (`tsx_fminsearch`, `tsx_ksdensity`, `tsx_signrank`,
`tsx_hist`, `tsx_prctile`).

## Documentation

Every exported function has its help page (title, description, usage,
*Arguments*, *Details*, *Value*, *References*, *Examples*, *See also*):
`help vident`, `doc vident`. The help of the package is `help matlab-new`
(`Contents.m`) and that of the datasets `help load_data`.

`tests/test_examples.m` checks that every help page has its sections and
that its examples run.

## Tests

```
cd matlab-new
matlab -batch "run_tests"
```

The tests (`tests/test_*.m`) compare the results with stored reference
results and with independent computations (mean relative difference
1e-6).
