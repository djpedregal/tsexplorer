function tsx_plot_plotband(x, f)
%TSX_PLOT_PLOTBAND Plot of plotband (plot.tsx_plotband in R).
import tsexplorer.internal.*
cl = x.call;
co = tsx_time_coords(x.dates, x.time);
ax = axes(f);
hold(ax, 'on');
if ~cl.all
    lab = x.series;
    if cl.overlay
        main = "Series " + lab + ": Series plot every " + cl.s + " samples";
        cols = hsv(size(x.data, 2));
    else
        main = "Series " + lab + ": Series Plot with 2*S.D. bands";
        cols = [0 0 0];
    end
    hl = plot(ax, co.x, x.data, 'LineStyle', '-');
    for k = 1:numel(hl)
        hl(k).Color = cols(min(k, size(cols, 1)), :);
    end
    yline(ax, x.mean, 'r');
    yline(ax, x.mean + [-2, 2] * x.sd, 'r:');
    ylabel(ax, "Series " + lab);
else
    cols = lines(size(x.data, 2));
    hl = plot(ax, co.x, x.data, 'LineStyle', '-');
    for k = 1:numel(hl)
        hl(k).Color = cols(k, :);
    end
    if cl.standard
        main = "Standardised Plot of All Series with 2*S.D. bands";
        ylabel(ax, "Standard scale");
        yline(ax, 0, 'r');
        yline(ax, [-2, 2], 'r:');
    else
        main = "Plot of All Series";
        ylabel(ax, "Units");
    end
    legend(ax, hl, x.series, 'Location', 'northwest', 'Box', 'off', 'FontSize', 8);
end
xlim(ax, co.xlim);
ylim(ax, x.ylim);
xlabel(ax, co.lab);
title(ax, main);
box(ax, 'on');
hold(ax, 'off');
end
