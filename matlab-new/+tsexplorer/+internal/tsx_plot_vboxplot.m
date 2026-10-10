function tsx_plot_vboxplot(x, f)
%TSX_PLOT_VBOXPLOT Plot of vboxplot (plot.tsx_vboxplot in R).
import tsexplorer.internal.*
s = x.call.s;
dated = ~isempty(x.group_dates);
if dated
    xlab = "Groups of " + s + " samples (start date)";
    labels = tsx_format_dates(x.group_dates);
else
    xlab = "Groups of every " + s + " samples apart";
    labels = [];
end
tsx_plot_boxstats(axes(f), x.stats.group, x.stats, x.highlight, ...
    "Series " + x.series + ": Box Plot (every " + s + " samples apart)", xlab, ...
    "Values of Series " + x.series, labels);
end
