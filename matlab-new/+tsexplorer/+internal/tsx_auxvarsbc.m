function a = tsx_auxvarsbc(y, order)
%TSX_AUXVARSBC Information criteria of a VAR(ORDER) with constant.
%   Fields: sigma, fpe, aic, aicc, sbc, hqc, e.
import tsexplorer.internal.*
if isvector(y)
    y = y(:);
end
n = size(y, 1);
m = size(y, 2);
if order == 0
    lagy = y;
else
    lagy = tsx_delay(y, 0:order);
end
x = [lagy(:, (m + 1):end), ones(size(lagy, 1), 1)];
yy = lagy(:, 1:m);
if any(isnan(y(:)))
    if order == 0
        e = y;
    else
        b = inv(tsx_nanprod(x', x)) * tsx_nanprod(x', yy);
        e = yy - tsx_nanprod(x, b);
    end
    s = tsx_nanprod(e', e);
else
    if order == 0
        e = y;
    else
        e = yy - x * (x \ yy);
    end
    s = e' * e;
end
sigma = s / n;
np = (size(lagy, 2) - m) / m;
ldet = log(det(sigma));
k = np * m * m + m;
a = struct('sigma', sigma, ...
    'fpe', ldet + log((n + k) / (n - k)), ...
    'aic', ldet + 2 * k / n, ...
    'aicc', ldet + (2 * k + 2) / (n - k - 2), ...
    'sbc', ldet + k * log(n) / n, ...
    'hqc', ldet + 2 * k * log(log(n)) / n, ...
    'e', e);
end
