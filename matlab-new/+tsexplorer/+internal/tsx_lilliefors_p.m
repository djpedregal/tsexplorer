function p = tsx_lilliefors_p(d, n)
%TSX_LILLIEFORS_P Approximate p-value of the Lilliefors test (interpolated
%   in a table of critical values).
import tsexplorer.internal.*
tabs = tsx_tables();
if n > 30
    crit = [0.736, 0.768, 0.805, 0.886, 1.031] / sqrt(n);
elseif n < 5
    p = NaN;
    return
else
    crit = tabs.lillie(n - 4, :);
end
p = tsx_interpol(crit, tabs.lillie_p, d, [0, 1]);
end
