function r = adftest(y, opts)
%ADFTEST Augmented Dickey-Fuller unit root tests (see help adftest).
%   R = tsexplorer.adftest(Y, lags=[], names=[]) is the function adftest.
%   It is called by its full name by the interface tooltest, so that this
%   test runs even when another function adftest (e.g. that of the
%   Econometrics Toolbox) comes first on the path.
%
%   See also adftest.
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
nr = m * numel(lags);
series = strings(nr, 1);
lag = zeros(nr, 1);
[rho0, t0, rho1, t1, c1, tc1, f1, rho2, t2, c2, tc2, d2, td2, f3] = deal(zeros(nr, 1));
row = 0;
for i = 1:m
    for p = lags
        row = row + 1;
        series(row) = names(i);
        lag(row) = p;
        [dy, dx] = tsx_adf_design(y(:, i), p);
        % no constant, no trend
        a = tsx_adf_ols(dy, dx(:, [1, (1:p) + 3]));
        rho0(row) = a.beta(1);
        t0(row) = (a.beta(1) - 1) / a.se(1);
        % constant
        a = tsx_adf_ols(dy, dx(:, [1, 2, (1:p) + 3]));
        vv = [a.beta(1) - 1; a.beta(2)];
        rho1(row) = a.beta(1);
        t1(row) = (a.beta(1) - 1) / a.se(1);
        c1(row) = a.beta(2);
        tc1(row) = a.beta(2) / a.se(2);
        f1(row) = vv' * (a.cov(1:2, 1:2) \ vv) / 2;
        % constant and trend
        a = tsx_adf_ols(dy, dx);
        vv = [a.beta(1) - 1; a.beta(3)];
        rho2(row) = a.beta(1);
        t2(row) = (a.beta(1) - 1) / a.se(1);
        c2(row) = a.beta(2);
        tc2(row) = a.beta(2) / a.se(2);
        d2(row) = a.beta(3);
        td2(row) = a.beta(3) / a.se(3);
        f3(row) = vv' * (a.cov([1, 3], [1, 3]) \ vv) / 2;
    end
end
none = table(series, lag, rho0, t0, adfcritical(t0, n, "t_none"), ...
    'VariableNames', {'series', 'lag', 'rho', 't', 'p_t'});
const = table(series, lag, rho1, t1, adfcritical(t1, n, "t_const"), c1, tc1, f1, ...
    adfcritical(f1, n, "f_const"), ...
    'VariableNames', {'series', 'lag', 'rho', 't', 'p_t', 'const', 't_const', 'f', 'p_f'});
trend = table(series, lag, rho2, t2, adfcritical(t2, n, "t_trend"), c2, tc2, d2, ...
    td2, f3, adfcritical(f3, n, "f_trend"), ...
    'VariableNames', {'series', 'lag', 'rho', 't', 'p_t', 'const', 't_const', 'trend', ...
                      't_trend', 'f', 'p_f'});
r = tsx_result("adftest", 'call', struct('lags', lags), 'series', names, 'n', n, ...
    'none', none, 'const', const, 'trend', trend);
end
