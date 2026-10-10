function r = vboxplot(y, opts)
%VBOXPLOT Box plot of a time series by groups of s consecutive observations.
%   For each group of s consecutive observations (e.g. each year of monthly
%   data) shows the mean, median, 25% and 75% percentiles, minimum and
%   maximum. Optionally highlights the observations of one position within
%   the groups (e.g. one month across years).
%
%   R = vboxplot(Y)
%   R = vboxplot(Y, s=12, series=1, highlight=0, names=[])
%
%   Arguments:
%     Y          Time series data (see as_tsx_matrix).
%     s          Length of the groups (seasonal period). Default 12,
%                limited to T / 2.
%     series     Series to analyse (index or name).
%     highlight  0 for none, or the position 1..s within the groups whose
%                values are highlighted.
%     names      Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vboxplot" "tsx_result"] with fields call,
%     series, stats (table with columns group, mean, median, p25, p75, min,
%     max), highlight (values highlighted, one per group) and group_dates
%     (date of the first observation of each group for dated inputs,
%     otherwise []).
%
%   Examples:
%     y = load_data("airpas");
%     r = vboxplot(y, highlight=7);
%     tsexplorer.print(r)
%     tsexplorer.plot(r)
%
%   See also tsexplorer.plot, vtboxplot, plotband.
arguments
    y
    opts.s = 12
    opts.series = 1
    opts.highlight = 0
    opts.names = []
end
import tsexplorer.internal.*
[y, names, dates] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
s = min(tsx_check_int(opts.s, "s"), floor(n / 2));
i = tsx_series_index(opts.series, names);
i = i(1);
ng = ceil(n / s);
zi = reshape([y(:, i); nan(ng * s - n, 1)], s, ng);
st = tsx_group_stats(zi);
st = [table((1:ng)', 'VariableNames', {'group'}), st];
highlight = min(max(0, round(opts.highlight)), s);
hv = zeros(0, 1);
if highlight > 0
    hv = y(highlight:s:n, i);
end
gd = [];
if ~isempty(dates)
    gd = dates(1:s:n);
end
r = tsx_result("vboxplot", 'call', struct('s', s, 'series', i, 'highlight', highlight), ...
    'series', names(i), 'stats', st, 'highlight', hv, 'group_dates', gd);
end
