function r = vhist(y, opts)
%VHIST Histogram with gaussian and non-parametric density estimates.
%   Histogram of one series with the density of a normal distribution with
%   the mean and standard deviation of the data and a kernel density
%   estimate (normal kernel), both scaled to the counts of the histogram.
%
%   R = vhist(Y)
%   R = vhist(Y, bins=[], series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     bins     Number of bins. Default ceil(sqrt(T)).
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vhist" "tsx_result"] with fields call,
%     series, hist (table with bin mid, lower, upper and count) and density
%     (table with x, normal and kernel, both scaled to counts, at 181
%     points).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vhist(vdif(log(y), [1 1], [1 12])))
%
%   See also tsexplorer.plot, vqqplot, gausstest.
arguments
    y
    opts.bins = []
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
bins = opts.bins;
if isempty(bins)
    bins = ceil(sqrt(size(y, 1)));
end
bins = tsx_check_int(bins, "bins");
i = tsx_series_index(opts.series, names);
i = i(1);
[h, dens] = tsx_hist_data(y(:, i), bins);
r = tsx_result("vhist", 'call', struct('bins', bins, 'series', i), 'series', names(i), ...
    'hist', h, 'density', dens);
end
