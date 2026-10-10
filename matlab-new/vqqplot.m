function r = vqqplot(y, opts)
%VQQPLOT Normal QQ plot.
%   Empirical quantiles of one series against the quantiles of a normal
%   distribution with the same mean and standard deviation, with the line
%   through the 25% and 75% quartiles.
%
%   R = vqqplot(Y)
%   R = vqqplot(Y, series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vqqplot" "tsx_result"] with fields call,
%     series, table (table with theoretical and empirical quantiles),
%     quartiles (struct with the x and y coordinates of the quartiles) and
%     line (struct with the end points x, y of the reference line).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vqqplot(vdif(log(y), [1 1], [1 12])))
%
%   See also tsexplorer.plot, vhist, gausstest.
arguments
    y
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
i = tsx_series_index(opts.series, names);
i = i(1);
zi = sort(y(~isnan(y(:, i)), i));
n = numel(zi);
qt = mean(zi) + tsx_sd(zi) * tsx_qnorm(((1:n)' - 0.5) / n);
x1 = tsx_prctile(qt, [25, 75]);
y1 = tsx_prctile(zi, [25, 75]);
beta = diff(y1) / diff(x1);
yini = y1(1) - (x1(1) - qt(1)) * beta;
yend = y1(2) + (qt(n) - x1(2)) * beta;
r = tsx_result("vqqplot", 'call', struct('series', i), 'series', names(i), ...
    'table', table(qt, zi, 'VariableNames', {'theoretical', 'empirical'}), ...
    'quartiles', struct('x', x1(:)', 'y', y1(:)'), ...
    'line', struct('x', [qt(1), qt(n)], 'y', [yini, yend]));
end
