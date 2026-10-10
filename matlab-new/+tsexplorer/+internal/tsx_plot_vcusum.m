function tsx_plot_vcusum(x, f)
%TSX_PLOT_VCUSUM Plot of vcusum (plot.tsx_vcusum in R): CUSUM and CUSUMSQ
%   with their 5% bands.
t = x.table;
co = tsexplorer.internal.tsx_time_coords(x.dates, t.t);
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact');
ax = nexttile(tl);
hold(ax, 'on');
plot(ax, co.x, t.cusum, 'k');
plot(ax, co.x, t.cusum_lower, 'r:');
plot(ax, co.x, t.cusum_upper, 'r:');
yline(ax, 0, 'r');
xlim(ax, co.xlim);
ylabel(ax, "CUSUM test");
title(ax, "Series " + x.series + ": CUSUM test with 5% Confidence Band");
box(ax, 'on');
hold(ax, 'off');
ax = nexttile(tl);
hold(ax, 'on');
plot(ax, co.x, t.cusumsq, 'k');
plot(ax, co.x, t.cusumsq_lower, 'r:');
plot(ax, co.x, t.cusumsq_upper, 'r:');
plot(ax, [co.x(1), co.x(end)], [min(t.cusumsq, [], 'omitnan'), max(t.cusumsq, [], 'omitnan')], 'r');
xlim(ax, co.xlim);
xlabel(ax, co.lab);
ylabel(ax, "CUSUMSQ test");
title(ax, "Series " + x.series + ": CUSUMSQ test with 5% Confidence Band");
box(ax, 'on');
hold(ax, 'off');
end
