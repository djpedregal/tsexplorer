function r = nltests(y, opts)
%NLTESTS Non-linearity tests based on squares.
%   McLeod-Li (portmanteau on the ACF of the squared series), Monti (on the
%   PACF of the squares) and Pena-Rodriguez (determinant of the
%   autocorrelation matrix of the squares) tests.
%
%   R = nltests(Y)
%   R = nltests(Y, ncoef=[], series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     ncoef    Number of lags. Default min(38, ceil(T / 4 / m * 2)).
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_nltests" "tsx_result"] with fields call,
%     series and table, a table with columns lag, acf, se_acf, q_mll,
%     p_mll, pacf, se_pacf, q_mt, p_mt, d_pr, p_pr (statistics and p-values
%     of the three tests for each lag).
%
%   References:
%     McLeod, A.I. and Li, W.K. (1983). Diagnostic checking ARMA time
%     series models using squared-residual autocorrelations. Journal of
%     Time Series Analysis, 4, 269-273.
%     Monti, A.C. (1994). A proposal for a residual autocorrelation test in
%     linear models. Biometrika, 81, 776-780.
%     Pena, D. and Rodriguez, J. (2002). A powerful portmanteau test of
%     lack of fit for time series. Journal of the American Statistical
%     Association, 97, 601-610.
%
%   Examples:
%     y = load_data("airpas");
%     r = nltests(vdif(log(y), [1 1], [1 12]), ncoef=12);
%     tsexplorer.print(r)
%     tsexplorer.plot(r)
%
%   See also tsexplorer.print, tsexplorer.plot, vtsay,
%   varsbc2, vbds.
arguments
    y
    opts.ncoef = []
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
i = tsx_series_index(opts.series, names);
i = i(1);
a = tsx_acf_pacf(y(:, i) .^ 2, ncoef, 0);
lags = (1:ncoef)';
rk = sqrt((n + 2) ./ (n - lags)) .* a.sacf;
d = zeros(ncoef, 1);
for k = 1:ncoef
    rm = toeplitz([1; rk(1:k)]);
    d(k) = -(n / (k + 1)) * log(abs(det(rm)));
end
pd = tsx_pgamma(d, 3 * lags .* (lags + 1) ./ (8 * lags + 4), 3 * lags ./ (4 * lags + 2), false);
tab = table(lags, a.sacf, a.se_acf, a.q, a.p_q, a.spacf, a.se_pacf, a.q_mt, a.p_q_mt, d, pd, ...
    'VariableNames', {'lag', 'acf', 'se_acf', 'q_mll', 'p_mll', 'pacf', 'se_pacf', 'q_mt', ...
                      'p_mt', 'd_pr', 'p_pr'});
r = tsx_result("nltests", 'call', struct('ncoef', ncoef, 'series', i), 'series', names(i), ...
    'table', tab);
end
