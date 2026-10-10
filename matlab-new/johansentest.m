function r = johansentest(y, opts)
%JOHANSENTEST Johansen cointegration tests.
%   Maximum eigenvalue and trace statistics of Johansen (1988) for the
%   number of cointegrating relations of a VAR model in levels with lag
%   lags, under three specifications of the deterministic terms (none,
%   constant, constant and linear trend). For one series the test is a unit
%   root test.
%
%   R = johansentest(Y)
%   R = johansentest(Y, lags=[], names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     lags     Lag order(s) of the VAR in levels (the VECM includes lag - 1
%              lagged differences). Default: 2:min(floor(sqrt(T)), 20) for
%              one series (lag 1 is removed) and min(floor(sqrt(T)), 20)
%              for several.
%     names    Optional names of the series.
%
%   Details:
%     P-values are approximate, interpolated (and linearly extrapolated,
%     clamped to [0, 1]) in tables of critical values for up to 5
%     non-stationary directions; beyond that they are NaN. The model
%     without deterministic terms uses the tables of Osterwald-Lenum (1992,
%     Table 0) and the model with an unrestricted constant those of
%     Johansen and Juselius (1990, Table A1). There are no tables for the
%     model with an unrestricted linear trend, whose p-values are NaN.
%
%   Value:
%     A struct of class ["tsx_johansentest" "tsx_result"] with fields
%     call, series and
%     * table: table with columns lag, type ("max" or "trace"), h0, h1
%       (number of cointegrating relations under the null and the
%       alternative), stat_none, p_none, stat_const, p_const, stat_trend,
%       p_trend,
%     * eigen: table with columns lag, i, eigen_none, lr_none, eigen_const,
%       lr_const, eigen_trend, lr_trend (eigenvalues and
%       -T log(1 - lambda_i)).
%
%   References:
%     Johansen, S. (1988). Statistical analysis of cointegration vectors.
%     Journal of Economic Dynamics and Control, 12, 231-254.
%     Johansen, S. and Juselius, K. (1990). Maximum likelihood estimation
%     and inference on cointegration. Oxford Bulletin of Economics and
%     Statistics, 52, 169-210.
%     Osterwald-Lenum, M. (1992). A note with quantiles of the asymptotic
%     distribution of the maximum likelihood cointegration rank test
%     statistics. Oxford Bulletin of Economics and Statistics, 54, 461-472.
%
%   Examples:
%     y = load_data("lydia_pinkham");
%     tsexplorer.print(johansentest(log(y)))
%
%   See also tsexplorer.print, adftest, vphillips.
arguments
    y
    opts.lags = []
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
lags = tsx_unitroot_lags(opts.lags, n, m);
if m == 1
    lags = lags(lags ~= 1);
end
if isempty(lags)
    error('tsexplorer:johansentest', ...
        "'lags' must include values greater than 1 for one series.");
end
nrow = 2 * m - 1;
h0 = repelem(0:(m - 1), 2)';
h0 = h0(1:nrow);
h1 = reshape([1:m; repmat(m, 1, m)], [], 1);
h1 = h1(1:nrow);
type = repmat(["max"; "trace"], m, 1);
type = type(1:nrow);
dets = ["none", "const", "trend"];
tab = table();
eig = table();
for L = lags
    stat = zeros(nrow, 3);
    lam = zeros(m, 3);
    lr = zeros(m, 3);
    for k = 1:3
        [lam(:, k), lr(:, k)] = tsx_johansen_eigen(y, L, dets(k));
        cum = flipud(cumsum(flipud(lr(:, k))));
        s = reshape([lr(:, k)'; cum'], [], 1);
        stat(:, k) = s(1:nrow);
    end
    p_none = tsx_johansen_p(stat(:, 1), m - h0, type, 1);
    p_const = tsx_johansen_p(stat(:, 2), m - h0, type, 3);
    p_trend = nan(nrow, 1);
    tl = table(repmat(L, nrow, 1), type, h0, h1, stat(:, 1), p_none, stat(:, 2), p_const, ...
        stat(:, 3), p_trend, ...
        'VariableNames', {'lag', 'type', 'h0', 'h1', 'stat_none', 'p_none', 'stat_const', ...
                          'p_const', 'stat_trend', 'p_trend'});
    tab = [tab; tl]; %#ok<AGROW>
    el = table(repmat(L, m, 1), (1:m)', lam(:, 1), lr(:, 1), lam(:, 2), lr(:, 2), lam(:, 3), ...
        lr(:, 3), 'VariableNames', {'lag', 'i', 'eigen_none', 'lr_none', 'eigen_const', ...
                                    'lr_const', 'eigen_trend', 'lr_trend'});
    eig = [eig; el]; %#ok<AGROW>
end
r = tsx_result("johansentest", 'call', struct('lags', lags), 'series', names, ...
    'table', tab, 'eigen', eig);
end
