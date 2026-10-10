function f = tsx_ksdensity(x, at)
%TSX_KSDENSITY Kernel density estimate with normal kernel and bandwidth
%   sigma * (4 / (3 n))^(1 / 5), sigma = MAD / 0.6745 (ksdensity defaults).
x = x(~isnan(x));
x = x(:);
n = numel(x);
sig = median(abs(x - median(x))) / 0.6745;
if sig <= 0
    sig = max(x) - min(x);
end
if sig > 0
    h = sig * (4 / (3 * n)) ^ (1 / 5);
else
    h = 1;
end
f = zeros(size(at));
for k = 1:numel(at)
    f(k) = mean(tsexplorer.internal.tsx_dnorm((at(k) - x) / h)) / h;
end
end
