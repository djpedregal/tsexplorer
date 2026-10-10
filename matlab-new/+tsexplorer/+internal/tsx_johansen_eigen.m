function [lambda, lr] = tsx_johansen_eigen(y, L, det)
%TSX_JOHANSEN_EIGEN Eigenvalues of the reduced rank regression (Johansen
%   1988). DET: "none", "const" or "trend". Column vectors in decreasing
%   order.
import tsexplorer.internal.*
n = size(y, 1);
m = size(y, 2);
dz = diff(y);
if L > 1
    lagy = tsx_delay(dz, 0:(L - 1));
else
    lagy = dz;
end
tz = size(lagy, 1);
x = lagy(:, (m + 1):end);
if det == "const" || det == "trend"
    x = [x, ones(tz, 1)];
end
if det == "trend"
    x = [x, (1:tz)'];
end
dzt = lagy(:, 1:m);
zlag = y((n - tz):(n - 1), :);
if size(x, 2) > 0
    ixx = inv(tsx_nanprod(x', x));
    u = dzt - tsx_nanprod(x, ixx * tsx_nanprod(x', dzt));
    v = zlag - tsx_nanprod(x, ixx * tsx_nanprod(x', zlag));
else
    u = dzt;
    v = zlag;
end
uu = tsx_nanprod(u', u) / tz;
vv = tsx_nanprod(v', v) / tz;
uv = tsx_nanprod(u', v) / tz;
lambda = real(eig(inv(vv) * uv' * inv(uu) * uv));
lambda = sort(lambda, 'descend');
lr = -n * log(1 - lambda);
end
