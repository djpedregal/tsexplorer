function r = sumstats(y, opts)
%SUMSTATS Summary descriptive statistics.
%   Computes for every series the number of data points, missing values,
%   percentiles, means (arithmetic, geometric and harmonic), dispersion
%   measures, skewness and kurtosis, a test of zero mean and, for more than
%   one series, the correlation matrix.
%
%   R = sumstats(Y)
%   R = sumstats(Y, gaussian=true, nsimul=3000, digits=4,
%                           seed=[], names=[])
%
%   Arguments:
%     Y         Time series data (see as_tsx_matrix).
%     gaussian  If true (default) the probability of zero mean is computed
%               from the t distribution; if false it is estimated by
%               bootstrap (nsimul replications) smoothed with a kernel
%               density.
%     nsimul    Number of bootstrap replications when gaussian = false.
%     digits    Number of decimals for printing.
%     seed      Optional seed for the bootstrap (the state of the random
%               number generator is restored on exit).
%     names     Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_sumstats" "tsx_result"] with fields:
%     * call: options used,
%     * series: names of the series,
%     * stats: table with one row per series and columns series, n,
%       missing, min, p10, p25, mean, p_mean_zero, geometric_mean,
%       harmonic_mean, median, mode, p75, p90, max, iqr, range, sd, var,
%       mean_abs_dev, median_abs_dev, mean_sd_ratio, skewness, kurtosis
%       (excess kurtosis). p_mean_zero is the two sided p-value of the test
%       of zero mean and range is max - min. mode is the most frequent value
%       (the smallest one in case of ties; with continuous data with no
%       repeated values it equals the minimum),
%     * cor: correlation matrix ([] for one series) and se_cor its standard
%       error 1/sqrt(T).
%
%   Examples:
%     tsexplorer.print(sumstats(load_data("airpas")))
%     tsexplorer.print(sumstats(load_data("scc"), ...
%         names=["A" "B" "C"]))
%
%   See also tsexplorer.print, gausstest.
arguments
    y
    opts.gaussian (1, 1) logical = true
    opts.nsimul (1, 1) double = 3000
    opts.digits (1, 1) double = 4
    opts.seed = []
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n_obs = size(y, 1);
m = size(y, 2);
pick = @(f) arrayfun(@(i) f(y(~isnan(y(:, i)), i)), (1:m)');
st = table(names(:), 'VariableNames', {'series'});
st.n = repmat(n_obs, m, 1);
st.missing = sum(isnan(y), 1)';
st.min = pick(@min);
st.p10 = pick(@(x) tsx_prctile(x, 10));
st.p25 = pick(@(x) tsx_prctile(x, 25));
st.mean = pick(@mean);
st.p_mean_zero = nan(m, 1);
st.geometric_mean = pick(@geometric_mean);
st.harmonic_mean = pick(@harmonic_mean);
st.median = pick(@median);
st.mode = pick(@tsx_mode);
st.p75 = pick(@(x) tsx_prctile(x, 75));
st.p90 = pick(@(x) tsx_prctile(x, 90));
st.max = pick(@max);
st.iqr = st.p75 - st.p25;
st.range = st.max - st.min;
st.sd = pick(@tsx_sd);
st.var = st.sd .^ 2;
st.mean_abs_dev = pick(@(x) mean(abs(x - mean(x))));
st.median_abs_dev = meda(y)';
st.mean_sd_ratio = st.mean ./ st.sd;
st.skewness = pick(@tsx_skewness);
st.kurtosis = pick(@tsx_kurtosis) - 3;
nn = st.n - st.missing;
tstat = st.mean ./ (st.sd ./ sqrt(nn));
if opts.gaussian
    st.p_mean_zero = 2 * tsx_pt(-abs(tstat), nn - 1);
else
    st.p_mean_zero = tsx_with_seed(opts.seed, @() tsx_auxsumstats(y, tstat, opts.nsimul));
end
cor = [];
if m > 1
    cor = tsx_nancorr(y);
end
r = tsx_result("sumstats", ...
    'call', struct('gaussian', opts.gaussian, 'nsimul', opts.nsimul, ...
                   'digits', opts.digits, 'seed', opts.seed), ...
    'series', names, 'stats', st, 'cor', cor, 'se_cor', 1 / sqrt(n_obs));
end

function g = geometric_mean(x)
if all(x > 0)
    g = exp(mean(log(x)));
else
    g = NaN;
end
end

function h = harmonic_mean(x)
x = x(abs(x) > 1e-5);
h = 1 / (sum(1 ./ x) / numel(x));
end
