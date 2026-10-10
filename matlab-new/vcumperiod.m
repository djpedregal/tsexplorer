function r = vcumperiod(y, opts)
%VCUMPERIOD Cumulative periodogram.
%   Normalised cumulative periodogram of one series with the 1% and 5%
%   Kolmogorov-Smirnov bands of the white noise hypothesis.
%
%   R = vcumperiod(Y)
%   R = vcumperiod(Y, series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vcumperiod" "tsx_result"] with fields call,
%     series, table (table with columns freq, frequency in cycles per
%     period from 0 to 0.5, and cum_periodogram) and bands (struct with the
%     half width of the 1% and 5% bands, p01 and p05).
%
%   References:
%     Box, G.E.P., Jenkins, G.M., Reinsel, G.C. and Ljung, G.M. (2015).
%     Time Series Analysis: Forecasting and Control, 5th ed. Wiley.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vcumperiod(vdif(log(y), [1 1], [1 12])))
%
%   See also tsexplorer.plot, vspectrum, vident.
arguments
    y
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
i = tsx_series_index(opts.series, names);
i = i(1);
z = y(:, i) - mean(y(:, i), 'omitnan');
t2 = floor(n / 2);
w = 2 * pi * (0:t2)' / n;
per = tsx_periodogram(z, w);
cum = cumsum(per);
if ~isnan(cum(end))
    cum = cum / cum(end);
end
r = tsx_result("vcumperiod", 'call', struct('series', i), 'series', names(i), ...
    'table', table(w / (2 * pi), cum, 'VariableNames', {'freq', 'cum_periodogram'}), ...
    'bands', struct('p01', 1.63 / sqrt(t2), 'p05', 1.36 / sqrt(t2)));
end
