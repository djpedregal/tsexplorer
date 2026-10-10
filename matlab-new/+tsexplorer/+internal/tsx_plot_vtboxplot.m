function tsx_plot_vtboxplot(x, f)
%TSX_PLOT_VTBOXPLOT Plot of vtboxplot (plot.tsx_vtboxplot in R).
s = x.call.s;
tsexplorer.internal.tsx_plot_boxstats(axes(f), x.stats.position, x.stats, x.highlight, ...
    "Series " + x.series + ": Transpose Box Plot (" + s + " samples)", ...
    "Groups of " + s + " samples", "Values of Series " + x.series);
end
