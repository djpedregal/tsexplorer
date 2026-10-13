# tsexplorer <img src="man/figures/logo.png" align="right" height="139" alt="tsexplorer logo" />

Diego J. Pedregal (Universidad de Castilla-La Mancha). License GPL-3.

Exploratory, descriptive and diagnostic tools for univariate and
multivariate time series, and tools to evaluate and compare forecasts. Every
tool is a pure function returning an object with `print()` and `plot()`
methods; the graphical interfaces `tooltest()` and `toolforecast()` give
interactive access to all of them, either as Tcl/Tk windows
(`gui = "tcltk"`, the default, no extra packages) or as Shiny applications
(`gui = "shiny"`). Data may have no dates or have them (`ts`, `zoo`, `xts` or a
`data.frame` with a date column); with dates, the plots and the forecast
tables show them.

## Installation

From GitHub:

```r
install.packages("remotes")
remotes::install_github("djpedregal/tsexplorer", subdir = "r")
```

## Use

```r
library(tsexplorer)
r <- vident(vdif(log(airpas), c(1, 1), c(1, 12)))
r          # table: ACF, PACF, Ljung-Box and Monti tests
plot(r)    # correlogram
adftest(log(airpas), lags = 1:4)
tooltest(airpas)                      # Tcl/Tk windows (default)
tooltest(airpas, gui = "shiny")       # same tool as a Shiny app
toolforecast(airpas, py, bands)       # py, bands: ts objects, like airpas
toolforecast(airpas, py, bands, gui = "shiny")
```

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

## Tests

The tests compare the functions with reference results stored in
`inst/extdata/reference/*.json`, computed on the example data and on
simulated series (`inst/extdata/reference/inputs/`), with tolerance 1e-6.

## Development

From this directory:

```r
devtools::document()
devtools::test()
devtools::check()
```
