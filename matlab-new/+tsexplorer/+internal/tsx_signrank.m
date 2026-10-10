function out = tsx_signrank(x, y)
%TSX_SIGNRANK Wilcoxon signed rank test of paired samples (ties within a
%   tolerance): sum of ranks of positive differences and two sided p-value
%   (exact if n <= 15, normal approximation without continuity correction
%   otherwise), as the function signrank.
import tsexplorer.internal.*
x = x(:);
y = y(:);
d = x - y;
epsd = tsx_eps(x) + tsx_eps(y);
ok = ~isnan(d);
d = d(ok);
epsd = epsd(ok);
if isempty(d)
    out = [NaN, NaN];
    return
end
nz = abs(d) > epsd;
d = d(nz);
epsd = epsd(nz);
n = numel(d);
if n == 0
    out = [0, 1];
    return
end
% mid ranks of |d| with ties (within tolerance) and tie adjustment
ad = abs(d);
[sx, o] = sort(ad);
se = epsd(o);
ranks = zeros(n, 1);
tieadj = 0;
k = 1;
while k <= n
    j = k;
    while j < n && sx(j) + se(j) >= sx(j + 1) - se(j + 1)
        j = j + 1;
    end
    ranks(k:j) = (k + j) / 2;
    nt = j - k + 1;
    if nt > 1
        tieadj = tieadj + nt * (nt - 1) * (nt + 1) / 2;
    end
    k = j + 1;
end
r = zeros(n, 1);
r(o) = ranks;
w = sum(r(d > 0));
if n <= 15
    p = min(1, 2 * tsx_signrank_exact(r, w));
else
    z = (w - n * (n + 1) / 4) / sqrt((n * (n + 1) * (2 * n + 1) - tieadj) / 24);
    p = 2 * tsx_pnorm(-abs(z));
end
out = [w, p];
end
