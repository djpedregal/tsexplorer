function r = gausstest(y, opts)
%GAUSSTEST Gaussianity tests.
%   Bera-Jarque and Kolmogorov-Smirnov-Lilliefors tests of normality for
%   every series and, for more than one series, the multivariate
%   Bera-Jarque test.
%
%   R = gausstest(Y)
%   R = gausstest(Y, digits=4, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     digits   Number of decimals for printing.
%     names    Optional names of the series.
%
%   Details:
%     The Lilliefors p-values are approximate: they are interpolated (and
%     linearly extrapolated, clamped to [0, 1]) in the table of critical
%     values of Lilliefors (1967) for p = 0.20, 0.15, 0.10, 0.05 and 0.01.
%
%   Value:
%     A struct of class ["tsx_gausstest" "tsx_result"] with fields call,
%     series, table (table with columns series, n, skewness, kurtosis
%     (excess), bj, p_bj, ksl, p_ksl) and, for more than one series,
%     bj_multi and p_bj_multi ([] for one series).
%
%   References:
%     Jarque, C.M. and Bera, A.K. (1987). A test for normality of
%     observations and regression residuals. International Statistical
%     Review, 55, 163-172.
%     Lilliefors, H.W. (1967). On the Kolmogorov-Smirnov test for normality
%     with mean and variance unknown. Journal of the American Statistical
%     Association, 62, 399-402.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.print(gausstest(y))
%     tsexplorer.print(gausstest(log(y)))
%
%   See also tsexplorer.print, vhist, vqqplot.
arguments
    y
    opts.digits (1, 1) double = 4
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
m = size(y, 2);
[skew, kurt, n, d, pd] = deal(zeros(m, 1));
for i = 1:m
    zi = y(~isnan(y(:, i)), i);
    n(i) = numel(zi);
    skew(i) = tsx_skewness(zi);
    kurt(i) = tsx_kurtosis(zi) - 3;
    d(i) = tsx_lilliefors_stat(zi);
    pd(i) = tsx_lilliefors_p(d(i), n(i));
end
bj = n / 6 .* (skew .^ 2 + kurt .^ 2 / 4);
tab = table(names(:), n, skew, kurt, bj, tsx_pchisq(bj, 2, false), d, pd, ...
    'VariableNames', {'series', 'n', 'skewness', 'kurtosis', 'bj', 'p_bj', 'ksl', 'p_ksl'});
bj_multi = [];
p_bj_multi = [];
if m > 1
    bj_multi = sum(bj);
    p_bj_multi = tsx_pchisq(bj_multi, 2 * m, false);
end
r = tsx_result("gausstest", 'call', struct('digits', opts.digits), 'series', names, ...
    'table', tab, 'bj_multi', bj_multi, 'p_bj_multi', p_bj_multi);
end
