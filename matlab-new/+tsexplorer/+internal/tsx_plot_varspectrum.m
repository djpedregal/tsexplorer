function tsx_plot_varspectrum(x, f)
%TSX_PLOT_VARSPECTRUM Plot of varspectrum (plot.tsx_varspectrum in R).
t = x.table;
xlog = x.call.xlog;
fx = tsexplorer.internal.tsx_period_axis(t.freq, xlog(1));
ax = axes(f);
if xlog(2)
    plot(ax, fx.x, log10(t.spectrum), 'k');
    ylabel(ax, "Log10(Power)");
else
    plot(ax, fx.x, t.spectrum, 'k');
    ylabel(ax, "Power");
end
xlim(ax, fx.lim);
xticks(ax, fx.ticks);
xticklabels(ax, fx.ticklabels);
xlabel(ax, fx.lab);
title(ax, "Series " + x.series + ": AR Spectrum(" + x.call.order + ")");
end
