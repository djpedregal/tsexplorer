% tsexplorer: exploratory, descriptive and diagnostic tools for time series
% Version 0.1.0 08-Oct-2026
%
% Exploratory, descriptive and diagnostic tools for univariate and
% multivariate time series, and tools to evaluate and compare forecasts
% (Diego J. Pedregal, Universidad de Castilla-La Mancha).
%
% Every tool is a pure function that takes a T x m data set (time in rows,
% series in columns; see as_tsx_matrix) and returns a struct whose field
% class is ["tsx_<function>" "tsx_result"], shown by tsexplorer.print and,
% when relevant, tsexplorer.plot (plot, print and fplot are in the package
% tsexplorer so that they do not hide the functions of MATLAB with the
% same names). The graphical interfaces tooltest and toolforecast give
% interactive access to all of them. Options are name-value arguments, e.g.
% vident(y, ncoef=24, npar=2).
%
% Plots and descriptive statistics
%   plotband          - Time series plot with confidence bands.
%   vboxplot          - Box plot of a time series by groups of s observations.
%   vtboxplot         - Transpose box plot of a time series.
%   vscatter          - Scatter plots.
%   sumstats          - Summary descriptive statistics.
%   vhist             - Histogram with gaussian and non-parametric densities.
%   vqqplot           - Normal QQ plot.
%   gausstest         - Gaussianity tests.
%
% Identification
%   vident            - Sample autocorrelation and partial autocorrelation.
%   vident2           - Multivariate sample autocorrelation functions.
%   varsbc            - Information criteria of AR and VAR models.
%   vgranger          - Granger causality tests.
%
% Heteroskedasticity
%   vcusum            - CUSUM and CUSUM of squares tests.
%   stdmean           - Standard deviation - mean plots.
%   testhet           - Heteroskedasticity tests.
%   vboxcox           - Box-Cox transformation.
%
% Unit roots and cointegration
%   adftest           - Augmented Dickey-Fuller unit root tests.
%   vphillips         - Phillips-Perron unit root tests.
%   johansentest      - Johansen cointegration tests.
%
% Non-linearity
%   nltests           - Non-linearity tests based on squares.
%   vtsay             - Tsay (1986) non-linearity test.
%   varsbc2           - Non-linearity test based on the SBC of squares.
%   vbds              - BDS test of independence.
%
% Spectral analysis
%   vcumperiod        - Cumulative periodogram.
%   vspectrum         - Spectrum, cross spectrum, gains and coherence.
%   varspectrum       - Autoregressive spectrum.
%
% Forecast evaluation
%   faccuracy         - Forecast accuracy measures.
%   fcompare          - Forecast comparison tests.
%   tsexplorer.fplot  - Plot of actual values and forecasts.
%
% Output
%   tsexplorer.print  - Text output of a result of the package.
%   tsexplorer.plot   - Plot of a result of the package.
%
% Graphical interfaces
%   tooltest          - Interactive test tool.
%   toolforecast      - Interactive forecasting tool.
%
% Utilities
%   as_tsx_matrix     - Convert input data to the matrix format of tsexplorer.
%   vdif              - Differencing of a vector of time series.
%   meda              - Median absolute deviation with respect to the median.
%   adfcritical       - Approximate p-values of Dickey-Fuller statistics.
%   tooltest_defaults - Default options of the tools of tooltest.
%   load_data         - Example datasets of the package.

