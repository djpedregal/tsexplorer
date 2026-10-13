# tsexplorer <img src="r/man/figures/logo.png" align="right" height="139" alt="tsexplorer logo" />

Diego J. Pedregal (Universidad de Castilla-La Mancha). License GPL-3.

Exploratory, descriptive and diagnostic tools for univariate and
multivariate time series (summary statistics, gaussianity tests, sample
autocorrelation functions, information criteria, Granger causality, unit root
and cointegration tests, heteroskedasticity and non-linearity tests, spectral
analysis) and tools to evaluate and compare forecasts (accuracy measures,
Diebold-Mariano, sign and Wilcoxon tests).

Every tool is a pure function that returns an object with print and plot
methods; the graphical interfaces `tooltest()` and `toolforecast()` give
interactive access to all of them.

The package is available in three languages, with the same functions, the
same arguments and defaults, the same fields in the results and the same
printed output. The three versions are validated against the same reference
results (`r/inst/extdata/reference`).

| Folder | Version | Interfaces | Requirements |
|---|---|---|---|
| [`r/`](https://github.com/djpedregal/tsexplorer/tree/main/r) | R package | Tcl/Tk or Shiny | R >= 4.1 |
| [`python/`](https://github.com/djpedregal/tsexplorer/tree/main/python) | Python package | tkinter | Python >= 3.10, numpy, scipy, pandas, matplotlib |
| [`matlab-new/`](https://github.com/djpedregal/tsexplorer/tree/main/matlab-new) | MATLAB functions | `uifigure` | MATLAB, no toolboxes |

## Installation from GitHub

**R** (from an R session; the Tcl/Tk interface needs no extra packages, the
Shiny one needs `shiny`):

```r
install.packages("remotes")
remotes::install_github("djpedregal/tsexplorer", subdir = "r")
library(tsexplorer)
```

**Python** (Python >= 3.10, from a terminal; numpy, scipy, pandas and
matplotlib are installed as dependencies):

```sh
pip install "git+https://github.com/djpedregal/tsexplorer.git#subdirectory=python"
```

**MATLAB** (no toolboxes needed): download the repository
([ZIP](https://github.com/djpedregal/tsexplorer/archive/refs/heads/main.zip))
or clone it, and add the folder `matlab-new` to the path:

```sh
git clone https://github.com/djpedregal/tsexplorer.git
```

```matlab
addpath('path/to/tsexplorer/matlab-new')
savepath   % optional: keep it in the path for future sessions
```

## Example

```r
library(tsexplorer)
r <- vident(vdif(log(airpas), c(1, 1), c(1, 12)))
r          # ACF, PACF, Ljung-Box and Monti tests
plot(r)    # correlogram
tooltest(airpas)
```

```python
from tsexplorer import load_data, vident, vdif, tooltest
import numpy as np
airpas = load_data("airpas")
vident(vdif(np.log(airpas), [1, 1], [1, 12]))
tooltest(airpas)
```

```matlab
airpas = load_data('airpas');
r = vident(vdif(log(airpas), [1 1], [1 12]))
tsexplorer.plot(r)
tooltest(airpas)
```

See the README of each folder for details.

## Tools

| Group | Functions |
|---|---|
| Plots and statistics | `plotband`, `vboxplot`, `vtboxplot`, `vscatter`, `sumstats` |
| Distribution | `vhist`, `vqqplot`, `gausstest` |
| Identification | `vident`, `vident2`, `varsbc`, `vgranger` |
| Heteroskedasticity | `vcusum`, `stdmean`, `testhet`, `vboxcox` |
| Unit roots and cointegration | `adftest`, `vphillips`, `johansentest` |
| Non-linearity | `nltests`, `vtsay`, `varsbc2`, `vbds` |
| Spectral analysis | `vcumperiod`, `vspectrum`, `varspectrum` |
| Forecast evaluation | `faccuracy`, `fcompare`, `fplot` |
| Interfaces | `tooltest`, `toolforecast` |

## License

GPL-3 (see [LICENSE](https://github.com/djpedregal/tsexplorer/blob/main/LICENSE)).
