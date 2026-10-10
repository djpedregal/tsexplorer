function v = tsx_mvar(y, order, const, partial)
%TSX_MVAR Least squares estimation of a VAR model with lags ORDER.
%   CONST: include a constant (default true); PARTIAL = true regresses
%   y(t - max(order) - 1) on the same regressors (used for partial lag
%   autocorrelations). Missing values are handled with tsx_nanprod().
%   Fields: p, se_p, sigma, aic, sbc, e, cov_p, inv_xx, lagy, x.
import tsexplorer.internal.*
if nargin < 3
    const = true;
end
if nargin < 4
    partial = false;
end
if isvector(y)
    y = y(:);
end
n = size(y, 1);
m = size(y, 2);
order = order(:)';
if ~isempty(order) && order(1) == 0
    order = order(2:end);
end
if isempty(order)
    v = [];
    return
end
if partial
    lagy = tsx_delay(y, [max(order) + 1, order]);
else
    lagy = tsx_delay(y, [0, order]);
end
x = lagy(:, (m + 1):end);
if const
    x = [x, ones(size(x, 1), 1)];
end
yy = lagy(:, 1:m);
if any(isnan(y(:)))
    inv_xx = inv(tsx_nanprod(x', x));
    p = inv_xx * tsx_nanprod(x', yy);
    e = yy - tsx_nanprod(x, p);
    s = tsx_nanprod(e', e);
else
    inv_xx = inv(x' * x);
    p = x \ yy;
    e = yy - x * p;
    s = e' * e;
end
sigma = s / n;
cov_p = kron(sigma, inv_xx);
se_p = reshape(sqrt(diag(cov_p)), size(p, 1), size(p, 2));
np = (size(lagy, 2) - m) / m;
k = np * m * m + m;
aic = (n * log(det(sigma)) + 2 * k) / n;
sbc = (n * log(det(sigma)) + k * log(n)) / n;
v = struct('p', p, 'se_p', se_p, 'sigma', sigma, 'aic', aic, 'sbc', sbc, 'e', e, ...
    'cov_p', cov_p, 'inv_xx', inv_xx, 'lagy', lagy, 'x', x);
end
