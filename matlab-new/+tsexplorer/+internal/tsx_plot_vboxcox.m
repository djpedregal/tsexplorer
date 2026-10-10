function tsx_plot_vboxcox(x, f)
%TSX_PLOT_VBOXCOX Plot of vboxcox (plot.tsx_vboxcox in R): normalised S.D.,
%   mean/S.D. and Guerrero criterion against lambda, with their optima.
g = x.grid;
if isempty(g)
    error('tsexplorer:plot', "No grid of lambdas to plot.");
end
v = [g.sd_std, g.mean_sd_std, g.criterion_std];
[~, o1] = min(v(:, 1));
[~, o2] = min(v(:, 2));
[~, o3] = max(v(:, 3));
opt = [o1, o2, o3];
lim = [min(v(:), [], 'omitnan'), max(v(:), [], 'omitnan')] + [-0.1, 0.1];
cols = [0 0 1; 1 0 0; 0 0 0];
ax = axes(f);
hold(ax, 'on');
for k = 1:3
    plot(ax, g.lambda, v(:, k), '-*', 'Color', cols(k, :));
end
for k = 1:3
    plot(ax, [g.lambda(opt(k)), g.lambda(opt(k))], [lim(1), v(opt(k), k)], ':', 'Color', cols(k, :));
end
xlim(ax, [min(g.lambda), max(g.lambda)] + [-0.1, 0.1]);
ylim(ax, lim);
xlabel(ax, "Lambda");
ylabel(ax, "Normalised S.D., Mean/S.D. & L-Lik");
fmt = @(z) tsexplorer.internal.tsx_format_num(z);
title(ax, "Series " + x.series(x.call.series) + ": S.D.(blue; " + fmt(g.lambda(opt(1))) + ...
    "), Mean/S.D.(red; " + fmt(g.lambda(opt(2))) + ") & L-Lik(black; " + ...
    fmt(g.lambda(opt(3))) + ")", 'FontSize', 9);
box(ax, 'on');
hold(ax, 'off');
end
