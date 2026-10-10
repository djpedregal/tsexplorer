function tsx_plot_vhist(x, f)
%TSX_PLOT_VHIST Plot of vhist (plot.tsx_vhist in R).
ax = axes(f);
tsexplorer.internal.tsx_plot_hist(ax, x.hist, x.density);
title(ax, "Series " + x.series + ...
    ": Histogram, Nonparametric estimate(green) & Theoretical normal(red)", 'FontSize', 9);
xlabel(ax, "Series " + x.series);
ylabel(ax, "Data points");
end
