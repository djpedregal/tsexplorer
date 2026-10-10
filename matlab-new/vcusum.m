function r = vcusum(y, opts)
%VCUSUM CUSUM and CUSUM of squares tests.
%   Cumulative sums of the standardised series (CUSUM) and of its squared
%   deviations from the mean (CUSUMSQ), with 5% confidence bands.
%
%   R = vcusum(Y)
%   R = vcusum(Y, series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vcusum" "tsx_result"] with fields call,
%     series and table, a table with columns t, cusum, cusum_lower,
%     cusum_upper, cusumsq, cusumsq_lower, cusumsq_upper, and dates (dates
%     of the rows for dated inputs, otherwise []).
%
%   References:
%     Brown, R.L., Durbin, J. and Evans, J.M. (1975). Techniques for
%     testing the constancy of regression relationships over time. Journal
%     of the Royal Statistical Society B, 37, 149-192.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vcusum(vdif(log(y), [1 1], [1 12])))
%
%   See also tsexplorer.plot, testhet, stdmean.
arguments
    y
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names, dates] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
i = tsx_series_index(opts.series, names);
i = i(1);
z = y(:, i);
ok = ~isnan(z);
zm = z(ok) - mean(z(ok));
cusum = nan(n, 1);
cusumsq = nan(n, 1);
cusum(ok) = cumsum(zm / tsx_sd(z(ok)));
cusumsq(ok) = cumsum(zm .^ 2 / sum(zm .^ 2));
t = (1:n)';
band = 0.948 * sqrt(n) + 2 * 0.948 * t / sqrt(n);
tab = table(t, cusum, -band, band, cusumsq, -0.32894 + t / n, 0.32894 + t / n, ...
    'VariableNames', {'t', 'cusum', 'cusum_lower', 'cusum_upper', 'cusumsq', ...
                      'cusumsq_lower', 'cusumsq_upper'});
r = tsx_result("vcusum", 'call', struct('series', i), 'series', names(i), 'table', tab, ...
    'dates', dates);
end
