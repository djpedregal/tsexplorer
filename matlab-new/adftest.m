function r = adftest(y, varargin)
%ADFTEST Augmented Dickey-Fuller unit root tests.
%   ADF regressions of z_t on z_(t-1), p lagged differences and the
%   deterministic terms of three models: no constant and no trend,
%   constant, and constant plus linear trend. The tests are the t
%   statistics of H0: rho = 1 and the F statistics Phi1 (rho = 1 and no
%   constant) and Phi3 (rho = 1 and no trend).
%
%   R = adftest(Y)
%   R = adftest(Y, lags=[], names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     lags     Number(s) of lagged differences included in the regressions.
%              Default: 1:min(floor(sqrt(T)), 20) for one series and
%              min(floor(sqrt(T)), 20) for several series. If the largest
%              lag exceeds T / 2 the test is computed only for floor(T / 2)
%              lags.
%     names    Optional names of the series.
%
%   Details:
%     P-values are approximate, interpolated in the tables of Dickey and
%     Fuller (see adfcritical). The F statistics are the Wald
%     statistics divided by the number of restrictions.
%
%   Value:
%     A struct of class ["tsx_adftest" "tsx_result"] with fields call,
%     series, n (sample size used for the p-values) and three tables, one
%     row per series and lag:
%     * none: series, lag, rho, t, p_t,
%     * const: as none plus const, t_const, f (Phi1), p_f,
%     * trend: as const plus trend, t_trend, with f being Phi3.
%
%   References:
%     Dickey, D.A. and Fuller, W.A. (1979). Distribution of the estimators
%     for autoregressive time series with a unit root. Journal of the
%     American Statistical Association, 74, 427-431.
%     Dickey, D.A. and Fuller, W.A. (1981). Likelihood ratio statistics for
%     autoregressive time series with a unit root. Econometrica, 49,
%     1057-1072.
%     Said, S.E. and Dickey, D.A. (1984). Testing for unit roots in
%     autoregressive-moving average models of unknown order. Biometrika,
%     71, 599-607.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.print(adftest(log(y), lags=1:4))
%
%   See also tsexplorer.print, adfcritical, vphillips,
%   johansentest.

% The computations are in tsexplorer.adftest, so that the interface
% tooltest runs this test even when another function adftest (e.g. that
% of the Econometrics Toolbox) comes first on the path.
r = tsexplorer.adftest(y, varargin{:});
end
