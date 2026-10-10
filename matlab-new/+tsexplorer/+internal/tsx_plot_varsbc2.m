function tsx_plot_varsbc2(x, f)
%TSX_PLOT_VARSBC2 Plot of varsbc2 (plot.tsx_varsbc2 in R).
t = x.table;
ax = axes(f);
plot(ax, t.lag, t.sbc, 'b-*');
grid(ax, 'on');
if x.linear
    kind = "Linear)";
else
    kind = "Non-Linear)";
end
title(ax, "Series " + x.series + ": SBC Criterion of Squared data (Min is " + x.best + ...
    ": Process is " + kind);
xlabel(ax, "lags");
ylabel(ax, "SBC");
end
