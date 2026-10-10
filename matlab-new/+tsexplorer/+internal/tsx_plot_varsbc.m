function tsx_plot_varsbc(x, f)
%TSX_PLOT_VARSBC Plot of varsbc (plot.tsx_varsbc in R): information criteria
%   (top) and p-values of the likelihood ratio tests (bottom).
import tsexplorer.internal.*
t = x.table;
b = x.best;
tl = tiledlayout(f, 4, 1, 'TileSpacing', 'compact');
ax = nexttile(tl, [3 1]);
hold(ax, 'on');
cols = [tsx_rcolor("blue"); tsx_rcolor("darkgreen"); tsx_rcolor("red")];
v = [t.aicc, t.sbc, t.hqc];
h = gobjects(1, 3);
for k = 1:3
    h(k) = plot(ax, t.lag, v(:, k), '-*', 'Color', cols(k, :));
end
grid(ax, 'on');
ylabel(ax, "Information Criteria");
title(ax, "Series " + tsx_series_label(x.series) + ": Information Criteria of AR Models");
legend(ax, h, ["AICc(" + b.aicc + ")", "SBC(" + b.sbc + ")", "HQC(" + b.hqc + ")"], ...
    'Location', 'northeast', 'Box', 'off');
set(ax, 'XTickLabel', []);
box(ax, 'on');
hold(ax, 'off');
ax2 = nexttile(tl);
hold(ax2, 'on');
plot(ax2, t.lag, t.p_chi, 'k-*');
p = t.p_chi(~isnan(t.p_chi));
if all(p > 0.3)
    ymax = max(p);
else
    ymax = 0.3;
end
ylim(ax2, [0, ymax]);
yline(ax2, 0.05, 'r:');
yline(ax2, 0.1, 'b:');
xlabel(ax2, "lags");
ylabel(ax2, "P-Chi");
box(ax2, 'on');
hold(ax2, 'off');
linkaxes([ax, ax2], 'x');
end
