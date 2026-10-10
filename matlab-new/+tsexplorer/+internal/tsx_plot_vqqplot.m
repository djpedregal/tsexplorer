function tsx_plot_vqqplot(x, f)
%TSX_PLOT_VQQPLOT Plot of vqqplot (plot.tsx_vqqplot in R).
t = x.table;
ax = axes(f);
hold(ax, 'on');
plot(ax, t.theoretical, t.empirical, 'k*', 'LineStyle', 'none');
plot(ax, x.line.x, x.line.y, 'r:');
plot(ax, x.quartiles.x, x.quartiles.y, 'r-o', 'LineWidth', 2);
title(ax, "Series " + x.series + ": Empirical Quantiles vs Gaussian Theoretical Quantiles", ...
    'FontSize', 9);
xlabel(ax, "Normal Theoretical Quantiles");
ylabel(ax, "Empirical Quantiles");
box(ax, 'on');
hold(ax, 'off');
end
