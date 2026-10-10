function r = vscatter(y, opts)
%VSCATTER Scatter plots.
%   Scatter plot of two series with the least squares line or, for
%   series = "all", the matrix of scatter plots with histograms in the
%   diagonal.
%
%   R = vscatter(Y)
%   R = vscatter(Y, bins=[], series=[1 2], names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix), at least two
%              series.
%     bins     Number of bins of the histograms. Default ceil(sqrt(T)).
%     series   Two series (indices or names; the first one on the
%              horizontal axis) or "all".
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vscatter" "tsx_result"] with fields call,
%     series, data (matrix of the series) and coef, a table with the least
%     squares lines of every ordered pair: x, y, intercept, slope.
%
%   Examples:
%     y = load_data("scc");
%     tsexplorer.plot(vscatter(y))
%     tsexplorer.plot(vscatter(y, series="all"))
%
%   See also tsexplorer.plot, sumstats.
arguments
    y
    opts.bins = []
    opts.series = [1, 2]
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
if m < 2
    error('tsexplorer:vscatter', "'vscatter' needs at least two series.");
end
bins = opts.bins;
if isempty(bins)
    bins = ceil(sqrt(n));
end
series = opts.series;
idx = tsx_series_index(series, names, true);
all = (ischar(series) || isstring(series)) && lower(string(series(1))) == "all";
if ~all && numel(idx) < 2
    error('tsexplorer:vscatter', 'Give two series or "all".');
end
if ~all
    idx = idx(1:2);
end
xs = strings(0, 1);
ys = strings(0, 1);
b0 = zeros(0, 1);
b1 = zeros(0, 1);
for i = 1:m
    for j = 1:m
        if i == j
            continue
        end
        b = tsx_line_fit(y(:, i), y(:, j));
        xs(end + 1, 1) = names(i); %#ok<AGROW>
        ys(end + 1, 1) = names(j); %#ok<AGROW>
        b0(end + 1, 1) = b(1); %#ok<AGROW>
        b1(end + 1, 1) = b(2); %#ok<AGROW>
    end
end
coef = table(xs, ys, b0, b1, 'VariableNames', {'x', 'y', 'intercept', 'slope'});
r = tsx_result("vscatter", 'call', struct('bins', bins, 'series', idx, 'all', all), ...
    'series', names(idx), 'data', y(:, idx), 'coef', coef);
end
