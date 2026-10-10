function p = tsx_johansen_p(x, g, type, dist)
%TSX_JOHANSEN_P Approximate p-values of the Johansen statistics.
%   G: number of non-stationary directions (m - h0); TYPE "max" or "trace";
%   DIST: 1, 2 or 3 (tables of the three deterministic specifications).
import tsexplorer.internal.*
tabs = tsx_tables();
type = string(type);
p = nan(numel(x), 1);
for i = 1:numel(x)
    if g(i) > 5 || isnan(x(i))
        continue
    end
    tab = tabs.joh.(type(i) + "_" + dist);
    p(i) = tsx_interpol(tab(g(i), :), tabs.joh_p, x(i), [0, 1]);
end
end
