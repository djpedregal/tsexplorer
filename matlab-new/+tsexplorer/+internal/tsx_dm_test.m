function out = tsx_dm_test(d, trunc, nofs)
%TSX_DM_TEST Diebold-Mariano statistic and two sided p-value.
d = d(:);
dt = d - mean(d, 'omitnan');
m1 = mean(d, 'omitnan');
f0 = tsexplorer.internal.tsx_sd(dt) ^ 2;
nd = numel(dt);
for k = 1:trunc
    f0 = f0 + 2 * sum(dt((k + 1):nd) .* dt(1:(nd - k)), 'omitnan') / nofs;
end
if isnan(f0)
    out = [NaN, NaN];
elseif f0 >= 0
    if f0 > 0
        stat = m1 / sqrt(f0 / nofs);
    else
        stat = 0;
    end
    out = [stat, 2 * tsexplorer.internal.tsx_pnorm(abs(stat), false)];
else
    out = [Inf, 0];
end
end
