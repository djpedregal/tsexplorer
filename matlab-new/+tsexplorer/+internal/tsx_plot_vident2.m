function tsx_plot_vident2(x, f, series)
%TSX_PLOT_VIDENT2 Plot of vident2 (plot.tsx_vident2 in R): ACF and partial
%   function of one series (SERIES = i) or cross correlations of two
%   (SERIES = [i j]): series i at time t with series j at time t - k (k < 0
%   side) and series i at time t - k with series j at time t (k > 0 side).
m = numel(x.series);
if isempty(series)
    series = 1;
end
if ischar(series) || isstring(series)
    [ok, idx] = ismember(string(series), x.series);
    if ~all(ok)
        idx = NaN;
    end
else
    idx = round(double(series));
end
if any(isnan(idx)) || any(idx < 1 | idx > m)
    error('tsexplorer:series', "Invalid 'series'.");
end
i = idx(1);
j = i;
if numel(idx) > 1
    j = idx(2);
end
nc = x.call.ncoef;
if x.call.type == 1
    lab = "Partial Autoregression";
else
    lab = "Partial Lag Autocorrelation";
end
if i == j
    lags = (1:nc)';
    v = [squeeze(x.acf(i, i, 2:end)), squeeze(x.pacf(i, i, 2:end))];
    se = [squeeze(x.se_acf(i, i, 2:end)), squeeze(x.se_pacf(i, i, 2:end))];
    titles = ["Series " + x.series(i) + ": Multivariate Sample Autocorrelation Function", ...
              "Series " + x.series(i) + ": Multivariate Sample " + lab + " Function"];
else
    lags = (-nc:nc)';
    side = @(arr, a, b) [flipud(squeeze(arr(a, b, 2:end))); arr(a, b, 1); squeeze(arr(b, a, 2:end))];
    v = [side(x.acf, i, j), side(x.pacf, i, j)];
    se = [side(x.se_acf, i, j), side(x.se_pacf, i, j)];
    ni = x.series(i);
    nj = x.series(j);
    titles = ["CCF between " + ni + "(t) and " + nj + "(t-k) [k < 0] and " + ni + ...
              "(t-k) and " + nj + "(t) [k > 0]", ...
              "PCCF between " + ni + "(t) and " + nj + "(t-k) [k < 0] and " + ni + ...
              "(t-k) and " + nj + "(t) [k > 0]"];
end
tsexplorer.internal.tsx_plot_correlogram(f, lags, v, se, x.call.s, titles);
end
