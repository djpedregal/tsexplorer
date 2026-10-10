function r = vphillips(y, opts)
%VPHILLIPS Phillips-Perron unit root tests.
%   Phillips-Perron Z_t statistics computed on the same three regressions
%   as adftest (no deterministic terms, constant, constant and
%   trend, each one including lag lagged differences). The long run
%   variance of the residuals is estimated with a Bartlett (Newey-West)
%   window with ncovs autocovariances.
%
%   R = vphillips(Y)
%   R = vphillips(Y, lags=[], ncovs=[], names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     lags     Number(s) of lagged differences included in the regressions.
%              Default: 1:min(floor(sqrt(T)), 20) for one series and
%              min(floor(sqrt(T)), 20) for several series. If the largest
%              lag exceeds T / 2 the test is computed only for floor(T / 2)
%              lags.
%     ncovs    Number of autocovariances of the residuals in the long run
%              variance. Default floor(4 * (T / 100)^0.25).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vphillips" "tsx_result"] with fields call,
%     series, n and the tables none, const and trend with columns series,
%     lag, rho, z_t (Phillips-Perron statistic) and p_value.
%
%   References:
%     Phillips, P.C.B. and Perron, P. (1988). Testing for a unit root in
%     time series regression. Biometrika, 75, 335-346.
%     Newey, W.K. and West, K.D. (1987). A simple, positive semi-definite,
%     heteroskedasticity and autocorrelation consistent covariance matrix.
%     Econometrica, 55, 703-708.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.print(vphillips(log(y), lags=1:3))
%
%   See also tsexplorer.print, adftest, adfcritical.
arguments
    y
    opts.lags = []
    opts.ncovs = []
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
lags = tsx_unitroot_lags(opts.lags, n, m);
ncovs = opts.ncovs;
if isempty(ncovs)
    ncovs = floor(4 * (n / 100) ^ 0.25);
end
ncovs = tsx_check_int(ncovs, "ncovs", 0);
mods = ["none", "const", "trend"];
cols = {1, [1, 2], [1, 2, 3]};
tabs = ["t_none", "t_const", "t_trend"];
nr = m * numel(lags);
series = strings(nr, 1);
lag = zeros(nr, 1);
rho = zeros(nr, 3);
zt = zeros(nr, 3);
row = 0;
for i = 1:m
    for p = lags
        row = row + 1;
        series(row) = names(i);
        lag(row) = p;
        [dy, dx] = tsx_adf_design(y(:, i), p);
        for k = 1:3
            a = tsx_adf_ols(dy, dx(:, [cols{k}, (1:p) + 3]));
            tstat = (a.beta(1) - 1) / a.se(1);
            rho(row, k) = a.beta(1);
            zt(row, k) = tsx_pp_correction(tstat, a.e, a.sse, a.s2, a.se(1), n, ncovs);
        end
    end
end
out = struct();
for k = 1:3
    out.(mods(k)) = table(series, lag, rho(:, k), zt(:, k), ...
        adfcritical(zt(:, k), n, tabs(k)), ...
        'VariableNames', {'series', 'lag', 'rho', 'z_t', 'p_value'});
end
r = tsx_result("vphillips", 'call', struct('lags', lags, 'ncovs', ncovs), 'series', names, ...
    'n', n, 'none', out.none, 'const', out.const, 'trend', out.trend);
end
