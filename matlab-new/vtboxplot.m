function r = vtboxplot(y, opts)
%VTBOXPLOT Transpose box plot of a time series.
%   Standardises each group of s consecutive observations and shows, for
%   each position 1..s within the groups (e.g. each month), the mean,
%   median, 25% and 75% percentiles, minimum and maximum across groups.
%   Optionally highlights one group (e.g. one year).
%
%   R = vtboxplot(Y)
%   R = vtboxplot(Y, s=12, series=1, highlight=0, names=[])
%
%   Arguments:
%     Y          Time series data (see as_tsx_matrix).
%     s          Length of the groups (seasonal period). Default 12,
%                limited to T / 2.
%     series     Series to analyse (index or name).
%     highlight  0 for none, or the group 1..ceil(T / s) to highlight.
%     names      Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vtboxplot" "tsx_result"] with fields call,
%     series, stats (table with columns position, mean, median, p25, p75,
%     min, max), data (matrix s x groups of standardised values) and
%     highlight.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vtboxplot(y, highlight=12))
%
%   See also tsexplorer.plot, vboxplot.
arguments
    y
    opts.s = 12
    opts.series = 1
    opts.highlight = 0
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
s = min(tsx_check_int(opts.s, "s"), floor(n / 2));
i = tsx_series_index(opts.series, names);
i = i(1);
ng = ceil(n / s);
zi = tsx_standardize(reshape([y(:, i); nan(ng * s - n, 1)], s, ng));
st = tsx_group_stats(zi');
st = [table((1:s)', 'VariableNames', {'position'}), st];
highlight = min(max(0, round(opts.highlight)), ng);
hv = zeros(0, 1);
if highlight > 0
    hv = zi(:, highlight);
end
r = tsx_result("vtboxplot", 'call', struct('s', s, 'series', i, 'highlight', highlight), ...
    'series', names(i), 'stats', st, 'data', zi, 'highlight', hv);
end
