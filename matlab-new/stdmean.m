function r = stdmean(y, opts)
%STDMEAN Standard deviation - mean plots.
%   Splits the series into groups of s consecutive observations (the first
%   T mod s observations are discarded) and plots a dispersion measure
%   against a location measure of each group, with the least squares line.
%   A positive slope suggests a transformation to stabilise the variance.
%
%   R = stdmean(Y)
%   R = stdmean(Y, s=12, type=0, numbers=true, series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     s        Length of the groups (seasonal period). Default 12.
%     type     0: standard deviation vs mean; 1: MEDA vs median; 2: range
%              vs mean.
%     numbers  Label each point with the number of its group in the plot.
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_stdmean" "tsx_result"] with fields call,
%     series, table (table with columns group, location, dispersion) and
%     coef (struct with the intercept and slope of the least squares line).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(stdmean(y))
%     tsexplorer.plot(stdmean(log(y), type=1))
%
%   See also tsexplorer.plot, vboxcox, meda.
arguments
    y
    opts.s = 12
    opts.type = 0
    opts.numbers (1, 1) logical = true
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
s = tsx_check_int(opts.s, "s", 2);
i = tsx_series_index(opts.series, names);
i = i(1);
i0 = mod(n, s) + 1;
ng = (n - i0 + 1) / s;
if ng < 2
    error('tsexplorer:stdmean', "Not enough data for groups of length 's'.");
end
zi = reshape(y(i0:n, i), s, ng);
if opts.type == 0
    loc = mean(zi, 1, 'omitnan')';
    disp = tsx_sd(zi)';
elseif opts.type == 1
    loc = median(zi, 1, 'omitnan')';
    disp = zeros(ng, 1);
    for k = 1:ng
        disp(k) = median(abs(zi(:, k) - loc(k)), 'omitnan');
    end
else
    loc = mean(zi, 1, 'omitnan')';
    disp = (max(zi, [], 1, 'omitnan') - min(zi, [], 1, 'omitnan'))';
end
b = tsx_line_fit(loc, disp);
r = tsx_result("stdmean", ...
    'call', struct('s', s, 'type', opts.type, 'numbers', opts.numbers, 'series', i), ...
    'series', names(i), ...
    'table', table((1:ng)', loc, disp, 'VariableNames', {'group', 'location', 'dispersion'}), ...
    'coef', struct('intercept', b(1), 'slope', b(2)));
end
