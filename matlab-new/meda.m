function d = meda(y)
%MEDA Median absolute deviation with respect to the median.
%   D = meda(Y)
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%
%   Value:
%     Row vector with the MEDA of each series (missing values are
%     ignored).
%
%   Examples:
%     meda(load_data("airpas"))
%
%   See also stdmean, sumstats.
y = as_tsx_matrix(y, trim = false);
d = nan(1, size(y, 2));
for j = 1:size(y, 2)
    x = y(:, j);
    d(j) = median(abs(x - median(x, 'omitnan')), 'omitnan');
end
end
