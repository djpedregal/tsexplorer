function tsx_plot_vspectrum(x, f)
%TSX_PLOT_VSPECTRUM Plot of vspectrum (plot.tsx_vspectrum in R): spectrum of
%   one series, or gains (left and right axes) and squared coherence of two.
t = x.table;
xlog = x.call.xlog;
fx = tsexplorer.internal.tsx_period_axis(t.freq, xlog(1));
if x.call.smooth > 1
    sm = "Smoothed Spectrum, Triangular window (" + x.call.smooth + ")";
else
    sm = "Periodogram";
end
if numel(x.series) == 1
    ax = axes(f);
    if xlog(2)
        plot(ax, fx.x, log10(t.spectrum), 'k');
        ylabel(ax, "Log10(Power)");
    else
        plot(ax, fx.x, t.spectrum, 'k');
        ylabel(ax, "Power");
    end
    set_axis(ax, fx);
    xlabel(ax, fx.lab);
    title(ax, "Series " + x.series + ": " + sm);
    return
end
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact');
ax = nexttile(tl);
g1 = t.gain12;
g2 = t.gain21;
ylab = "Gains";
if xlog(2)
    g1 = log10(g1);
    g2 = log10(g2);
    ylab = "log(Gains)";
end
yyaxis(ax, 'left');
plot(ax, fx.x, g1, 'k-');
ylabel(ax, ylab);
ax.YAxis(1).Color = [0 0 0];
yyaxis(ax, 'right');
plot(ax, fx.x, g2, 'r-');
ax.YAxis(2).Color = [1 0 0];
set_axis(ax, fx);
title(ax, "Gains: " + x.series(2) + " <- " + x.series(1) + " (left - black) and " + ...
    x.series(1) + " <- " + x.series(2) + " (right - red)", 'FontSize', 9);
ax = nexttile(tl);
plot(ax, fx.x, t.coherence, 'k');
ylim(ax, [0, 1.1]);
set_axis(ax, fx);
xlabel(ax, fx.lab);
ylabel(ax, "Coherence");
main = "Squared Coherence: " + x.series(1) + " - " + x.series(2);
if x.call.smooth > 1
    main = main + ". " + sm;
end
title(ax, main, 'FontSize', 9);
end

function set_axis(ax, fx)
xlim(ax, fx.lim);
xticks(ax, fx.ticks);
xticklabels(ax, fx.ticklabels);
end
