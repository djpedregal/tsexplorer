function tsx_plot_vcumperiod(x, f)
%TSX_PLOT_VCUMPERIOD Plot of vcumperiod (plot.tsx_vcumperiod in R):
%   cumulative periodogram with the 1% (red) and 5% (black) bands.
t = x.table;
b = [x.bands.p01, x.bands.p05];
ax = axes(f);
hold(ax, 'on');
plot(ax, t.freq, t.cum_periodogram, 'k');
plot(ax, [0, 0.5], [0, 1], 'r');
plot(ax, [0, 0.5], [b(1), 1 + b(1)], 'r:');
plot(ax, [0, 0.5], [-b(1), 1 - b(1)], 'r:');
plot(ax, [0, 0.5], [b(2), 1 + b(2)], 'k:');
plot(ax, [0, 0.5], [-b(2), 1 - b(2)], 'k:');
xlim(ax, [0, 0.5]);
ylim(ax, [min([t.cum_periodogram; -b(1)], [], 'omitnan'), max([t.cum_periodogram; 1 + b(1)], [], 'omitnan')]);
xlabel(ax, "Frequency");
ylabel(ax, "Cumulative Power");
title(ax, "Series " + x.series + ": Cumulative Periodogram (1% red; 5% black)");
box(ax, 'on');
hold(ax, 'off');
end
