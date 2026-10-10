function r = vtsay(y, opts)
%VTSAY Tsay (1986) non-linearity test.
%   Tsay (1986) F test: the residuals e_t of an AR(lags) model with
%   constant are regressed on the cross products z_(t-i) z_(t-j) (i <= j),
%   previously orthogonalised with respect to the constant and the lags.
%   With k = p (p + 1) / 2 products and n observations,
%       F = ((sum e_t^2 - sum u_t^2) / k) / (sum u_t^2 / (n - p - k - 1)),
%   u_t being the residuals of the auxiliary regression, follows an
%   F(k, n - p - k - 1) distribution under linearity. Missing values
%   remove the corresponding rows.
%
%   R = vtsay(Y)
%   R = vtsay(Y, lags=4, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     lags     Order of the AR model (at least 2). Default 4.
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vtsay" "tsx_result"] with fields call,
%     series, table (table with columns series, f, df1, df2, p_value) and
%     regressions (table with the auxiliary regression of the AR residuals
%     on the orthogonalised products: series, variable, beta, t, p_value,
%     two sided).
%
%   References:
%     Tsay, R.S. (1986). Nonlinearity tests for time series. Biometrika,
%     73, 461-466.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.print(vtsay(vdif(log(y), [1 1], [1 12])))
%
%   See also tsexplorer.print, nltests, vbds.
arguments
    y
    opts.lags = 4
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
m = size(y, 2);
lags = max(2, max(round(opts.lags)));
labs = strings(0, 1);
for i = 1:lags
    for j = i:lags
        labs(end + 1, 1) = "z(t-" + i + ")*z(t-" + j + ")"; %#ok<AGROW>
    end
end
kk = lags * (lags + 1) / 2;
f = nan(m, 1);
df2 = nan(m, 1);
p_value = nan(m, 1);
regs = table();
for s = 1:m
    x = tsx_delay(y(:, s), 0:lags);
    x = x(all(~isnan(x), 2), :);
    n = size(x, 1);
    xl = [ones(n, 1), x(:, 2:end)];
    e = tsx_ols(x(:, 1), xl).e;
    xx = zeros(n, 0);
    for i = 1:lags
        for j = i:lags
            xx = [xx, tsx_ols(xl(:, i + 1) .* xl(:, j + 1), xl).e]; %#ok<AGROW>
        end
    end
    a = tsx_ols(e, xx);
    d2 = n - lags - kk - 1;
    if d2 < 1
        error('tsexplorer:vtsay', "Too few observations for the Tsay test with %d lags.", lags);
    end
    s2 = a.sse / d2;
    fs = ((sum(e .^ 2) - a.sse) / kk) / s2;
    t = a.beta(:) ./ sqrt(diag(s2 * a.ixx));
    f(s) = fs;
    df2(s) = d2;
    p_value(s) = tsx_pf(fs, kk, d2, false);
    regs = [regs; table(repmat(names(s), kk, 1), labs, a.beta(:), t, 2 * tsx_pt(-abs(t), d2), ...
        'VariableNames', {'series', 'variable', 'beta', 't', 'p_value'})]; %#ok<AGROW>
end
tab = table(names(:), f, repmat(kk, m, 1), df2, p_value, ...
    'VariableNames', {'series', 'f', 'df1', 'df2', 'p_value'});
r = tsx_result("vtsay", 'call', struct('lags', lags), 'series', names, 'table', tab, ...
    'regressions', regs);
end
