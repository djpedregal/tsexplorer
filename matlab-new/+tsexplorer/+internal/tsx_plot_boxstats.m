function tsx_plot_boxstats(ax, xv, st, hv, main, xlab, ylab, labels)
%TSX_PLOT_BOXSTATS Statistics of groups: mean (red), median (black), 25% and
%   75% percentiles (red dotted), maximum and minimum (blue stars), and the
%   highlighted values HV (black line with points).
import tsexplorer.internal.*
if nargin < 8
    labels = [];
end
xv = xv(:);
hold(ax, 'on');
h1 = plot(ax, xv, st.mean, 'r', 'LineWidth', 2);
h2 = plot(ax, xv, st.median, 'k', 'LineWidth', 2);
h3 = plot(ax, xv, st.p25, 'r:');
plot(ax, xv, st.p75, 'r:');
h4 = plot(ax, xv, st.min, 'b*', 'LineStyle', 'none');
plot(ax, xv, st.max, 'b*', 'LineStyle', 'none');
if ~isempty(hv)
    plot(ax, (1:numel(hv))', hv(:), 'k.-', 'MarkerSize', 12);
end
lim = [min([st.min; st.max; hv(:)], [], 'omitnan'), max([st.min; st.max; hv(:)], [], 'omitnan')];
if lim(1) < lim(2)
    ylim(ax, lim);
end
xlim(ax, [0, max(xv) + 1]);
if ~isempty(labels)
    xticks(ax, xv);
    xticklabels(ax, labels);
end
title(ax, main);
xlabel(ax, xlab);
ylabel(ax, ylab);
legend(ax, [h1, h2, h3, h4], ["Mean", "Median", "25% and 75% Percentiles", ...
    "Maximum and Minimum"], 'Location', 'northwest', 'Box', 'off', 'FontSize', 8);
box(ax, 'on');
hold(ax, 'off');
end
