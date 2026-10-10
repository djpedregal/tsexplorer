function tsx_plot_stdmean(x, f)
%TSX_PLOT_STDMEAN Plot of stdmean (plot.tsx_stdmean in R): dispersion
%   against location of the groups, least squares line and group numbers.
switch x.call.type
    case 0
        lab = ["Mean", "Standard Deviation", "Standard Deviation - Mean Plot"];
    case 1
        lab = ["Median", "MEDA", "MEDA - Median Plot"];
    otherwise
        lab = ["Mean", "Range", "Range - Mean Plot"];
end
t = x.table;
ax = axes(f);
hold(ax, 'on');
plot(ax, t.location, t.dispersion, 'b.', 'MarkerSize', 14, 'LineStyle', 'none');
xl = [min(t.location), max(t.location)];
plot(ax, xl, x.coef.intercept + x.coef.slope * xl, 'r');
xlabel(ax, lab(1));
ylabel(ax, lab(2));
title(ax, "Series " + x.series + ": " + lab(3));
box(ax, 'on');
if x.call.numbers
    yl = ylim(ax);
    inc = diff(yl) / 30;
    text(ax, t.location, t.dispersion + inc, string(t.group), 'FontSize', 8, ...
        'HorizontalAlignment', 'center');
end
hold(ax, 'off');
end
