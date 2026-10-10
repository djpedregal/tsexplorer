function r = vident(y, opts)
%VIDENT Sample autocorrelation and partial autocorrelation functions.
%   Univariate sample ACF and PACF of one series, with their standard
%   errors (Bartlett for the ACF, 1/sqrt(T) for the PACF), the Ljung-Box
%   portmanteau test on the ACF and the Monti (1994) test on the PACF.
%
%   R = vident(Y)
%   R = vident(Y, ncoef=[], s=12, npar=0, series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     ncoef    Number of lags. Default min(38, ceil(T / 4 / m * 2)),
%              limited to T - 5.
%     s        Seasonal period, only used to highlight the seasonal lags in
%              the plot.
%     npar     Number of estimated parameters when Y is a set of residuals;
%              the degrees of freedom of the portmanteau tests are
%              lag - npar.
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vident" "tsx_result"] with fields call,
%     series (name of the series analysed) and table, a table with columns
%     lag, acf, se_acf, q_lb, p_lb, pacf, se_pacf, q_mt, p_mt.
%
%   References:
%     Ljung, G.M. and Box, G.E.P. (1978). On a measure of lack of fit in
%     time series models. Biometrika, 65, 297-303.
%     Monti, A.C. (1994). A proposal for a residual autocorrelation test in
%     linear models. Biometrika, 81, 776-780.
%
%   Examples:
%     y = load_data("airpas");
%     r = vident(vdif(log(y), [1 1], [1 12]));
%     tsexplorer.print(r)
%     tsexplorer.plot(r)
%
%   See also tsexplorer.print, tsexplorer.plot, vident2,
%   nltests.
arguments
    y
    opts.ncoef = []
    opts.s = 12
    opts.npar = 0
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
ncoef = opts.ncoef;
if isempty(ncoef)
    ncoef = min(38, ceil(n / 4 / m * 2));
end
ncoef = min(tsx_check_int(ncoef, "ncoef"), n - 5);
if ncoef < 1
    error('tsexplorer:vident', "Too few data points.");
end
i = tsx_series_index(opts.series, names);
i = i(1);
a = tsx_acf_pacf(y(:, i), ncoef, opts.npar);
tab = table((1:ncoef)', a.sacf, a.se_acf, a.q, a.p_q, a.spacf, a.se_pacf, a.q_mt, a.p_q_mt, ...
    'VariableNames', {'lag', 'acf', 'se_acf', 'q_lb', 'p_lb', 'pacf', 'se_pacf', 'q_mt', 'p_mt'});
r = tsx_result("vident", ...
    'call', struct('ncoef', ncoef, 's', opts.s, 'npar', opts.npar, 'series', i), ...
    'series', names(i), 'table', tab);
end
