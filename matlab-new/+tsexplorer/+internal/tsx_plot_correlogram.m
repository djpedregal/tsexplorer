function tsx_plot_correlogram(f, lags, values, se, s, titles)
%TSX_PLOT_CORRELOGRAM Correlogram bars with 2 standard error bands, seasonal
%   lags drawn in red dotted lines (one panel per column of VALUES).
k = size(values, 2);
tl = tiledlayout(f, k, 1, 'TileSpacing', 'compact');
lags = lags(:);
for j = 1:k
    ax = nexttile(tl);
    hold(ax, 'on');
    v = values(:, j);
    band = 2 * se(:, j);
    seas = mod(lags, s) == 0;
    ns = find(~seas);
    if ~isempty(ns)
        plot(ax, [lags(ns), lags(ns)]', [zeros(numel(ns), 1), v(ns)]', 'Color', 'b');
    end
    sn = find(seas);
    if ~isempty(sn)
        plot(ax, [lags(sn), lags(sn)]', [zeros(numel(sn), 1), v(sn)]', 'r:');
    end
    yline(ax, 0, 'b');
    plot(ax, lags, band, 'r:');
    plot(ax, lags, -band, 'r:');
    lim = [min([v; band; -band], [], 'omitnan'), max([v; band; -band], [], 'omitnan')];
    ylim(ax, lim + [-0.05, 0.05]);
    xlim(ax, [min(lags) - 1, max(lags) + 1]);
    title(ax, titles(j), 'FontSize', 9);
    ylabel(ax, 'Correlation');
    if j == k
        xlabel(ax, 'Lags');
    end
    box(ax, 'on');
    hold(ax, 'off');
end
end
