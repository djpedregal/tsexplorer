function tsx_plot_vscatter(x, f)
%TSX_PLOT_VSCATTER Plot of vscatter (plot.tsx_vscatter in R): one scatter
%   plot with the least squares line, or the scatter matrix of all the
%   series with their histograms in the diagonal.
import tsexplorer.internal.*
d = x.data;
if ~x.call.all
    b = x.coef(x.coef.x == x.series(1) & x.coef.y == x.series(2), :);
    ax = axes(f);
    hold(ax, 'on');
    plot(ax, d(:, 1), d(:, 2), 'b*', 'LineStyle', 'none');
    xl = [min(d(:, 1), [], 'omitnan'), max(d(:, 1), [], 'omitnan')];
    plot(ax, xl, b.intercept + b.slope * xl, 'r');
    xlabel(ax, x.series(1));
    ylabel(ax, x.series(2));
    title(ax, "Scatter Plot: Series " + x.series(1) + " vs " + x.series(2));
    box(ax, 'on');
    hold(ax, 'off');
    return
end
m = size(d, 2);
tl = tiledlayout(f, m, m, 'TileSpacing', 'none', 'Padding', 'compact');
for i = 1:m
    for j = 1:m
        ax = nexttile(tl);
        if i == j
            [h, dens] = tsx_hist_data(d(:, i), x.call.bins);
            tsx_plot_hist(ax, h, dens);
        else
            b = x.coef(x.coef.x == x.series(j) & x.coef.y == x.series(i), :);
            hold(ax, 'on');
            plot(ax, d(:, j), d(:, i), 'b.', 'LineStyle', 'none');
            xl = [min(d(:, j), [], 'omitnan'), max(d(:, j), [], 'omitnan')];
            plot(ax, xl, b.intercept + b.slope * xl, 'r');
            box(ax, 'on');
            hold(ax, 'off');
        end
        set(ax, 'XTick', [], 'YTick', []);
        if i == m
            xlabel(ax, x.series(j));
        end
        if j == 1
            ylabel(ax, x.series(i));
        end
    end
end
title(tl, "Scatter Plots for All Series");
end
