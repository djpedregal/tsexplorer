function tsx_plot_hist(ax, hist, density)
%TSX_PLOT_HIST Histogram bars (light steel blue) with the normal (red) and
%   kernel (green) densities, scaled to the counts.
import tsexplorer.internal.*
hold(ax, 'on');
for k = 1:height(hist)
    patch(ax, [hist.lower(k), hist.upper(k), hist.upper(k), hist.lower(k)], ...
        [0, 0, hist.count(k), hist.count(k)], tsx_rcolor("lightsteelblue"), ...
        'EdgeColor', tsx_rcolor("navy"));
end
plot(ax, density.x, density.normal, 'Color', 'r', 'LineWidth', 2);
plot(ax, density.x, density.kernel, 'Color', tsx_rcolor("green3"), 'LineWidth', 2);
xlim(ax, [min(hist.lower), max(hist.upper)]);
ylim(ax, [0, max([hist.count; density.normal; density.kernel])]);
box(ax, 'on');
hold(ax, 'off');
end
