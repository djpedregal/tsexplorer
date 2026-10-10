function tsx_plot_vident(x, f)
%TSX_PLOT_VIDENT Plot of vident (plot.tsx_vident in R).
t = x.table;
tsexplorer.internal.tsx_plot_correlogram(f, t.lag, [t.acf, t.pacf], [t.se_acf, t.se_pacf], ...
    x.call.s, ["Series " + x.series + ": Univariate Sample Autocorrelation Function", ...
               "Series " + x.series + ": Univariate Sample Partial Autocorrelation Function"]);
end
