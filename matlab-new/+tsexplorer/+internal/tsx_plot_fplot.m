function tsx_plot_fplot(x, f)
%TSX_PLOT_FPLOT Plot of fplot (plot.tsx_fplot in R): actual values,
%   forecasts and their bands (top), forecast errors (bottom), with the
%   forecast origin as a vertical line.
import tsexplorer.internal.*
t = x.time;
names = ["red", "darkgreen", "magenta3", "gold3", "blue", "cyan3"];
nf = size(x.forecasts, 2);
cols = zeros(nf, 3);
for k = 1:nf
    cols(k, :) = tsx_rcolor(names(mod(k - 1, numel(names)) + 1));
end
all = isequal(x.call.forecast, "all");
if all
    flabs = "F" + (1:nf);
else
    flabs = "F" + x.call.forecast;
end
if isempty(x.dates)
    co = tsx_time_coords([], t);
    xo = x.origin;
else
    co = tsx_time_coords(x.dates(t), t);
    xo = [];
    if x.origin > 0
        xo = x.dates(x.origin);
    end
end
if x.origin <= 0
    xo = [];
end
tl = tiledlayout(f, 4, 1, 'TileSpacing', 'compact');
ax = nexttile(tl, [3 1]);
hold(ax, 'on');
h = plot(ax, co.x, x.actual(t), 'k');
hf = gobjects(1, nf);
for k = 1:nf
    hf(k) = plot(ax, co.x, x.forecasts(t, k), 'Color', cols(k, :));
    if ~isempty(x.lower)
        plot(ax, co.x, x.lower(t, k), ':', 'Color', cols(k, :));
        plot(ax, co.x, x.upper(t, k), ':', 'Color', cols(k, :));
    end
end
if ~isempty(xo)
    xline(ax, xo, 'k', 'LineWidth', 2);
end
v = [x.actual(:); x.forecasts(:); x.lower(:); x.upper(:)];
ylim(ax, finite_range(v));
xlim(ax, co.xlim);
ylabel(ax, "Series " + x.series);
title(ax, "Series " + x.series + ": Series Plot, Forecast with confidence bands and Errors");
legend(ax, [h, hf], [x.series, flabs], 'Location', 'northwest', 'Box', 'off', 'FontSize', 8);
set(ax, 'XTickLabel', []);
box(ax, 'on');
hold(ax, 'off');
ax2 = nexttile(tl);
hold(ax2, 'on');
e = x.errors(t, :);
for k = 1:nf
    plot(ax2, co.x, e(:, k), 'Color', cols(k, :));
end
el = finite_range(e(:));
if el(1) == el(2)
    el = [-0.1, 0.1];
end
if all
    el(1) = 0;
    ylabel(ax2, "ABS(E)");
else
    yline(ax2, 0, 'k:');
    ylabel(ax2, "Errors");
end
if ~isempty(xo)
    xline(ax2, xo, 'k', 'LineWidth', 2);
end
if el(1) < el(2)
    ylim(ax2, el);
end
xlim(ax2, co.xlim);
xlabel(ax2, co.lab);
box(ax2, 'on');
hold(ax2, 'off');
end

function r = finite_range(v)
v = v(isfinite(v));
if isempty(v)
    r = [-0.1, 0.1];
else
    r = [min(v), max(v)];
    if r(1) == r(2)
        r = r + [-0.1, 0.1];
    end
end
end
