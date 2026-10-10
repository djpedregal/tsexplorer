function r = varspectrum(y, opts)
%VARSPECTRUM Autoregressive spectrum.
%   Spectrum of an AR model of order 'order' (with constant) fitted by
%   least squares to one series,
%       f(w) = sigma^2 / (2 pi) |1 / phi(exp(-i w))|^2,
%   in the same scale as the periodogram of vspectrum.
%
%   R = varspectrum(Y)
%   R = varspectrum(Y, order=16, nfreq=[], xlog=[false true],
%                              series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     order    Order of the AR model. Default 16 (limited to T / 2).
%     nfreq    Number of frequencies in [0, pi). 0 or [] uses the Fourier
%              frequencies 2 pi j / T; values below 10 are replaced by
%              floor(T / 2). Default floor(T / 2).
%     xlog     Logical vector of length 2: logarithmic scale for the
%              frequency (period) axis and for the power axis in the plot.
%              Default [false true].
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_varspectrum" "tsx_result"] with fields call,
%     series, ar (estimated AR coefficients), sigma2 (innovation variance)
%     and table (table with columns freq, radians, and spectrum).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(varspectrum(vdif(log(y)), order=14))
%
%   See also tsexplorer.plot, vspectrum.
arguments
    y
    opts.order = 16
    opts.nfreq = []
    opts.xlog = [false, true]
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
t2 = floor(n / 2);
nfreq = opts.nfreq;
if isempty(nfreq)
    nfreq = t2;
end
if nfreq == 0
    freq = 2 * pi * (0:t2)' / n;
else
    if nfreq < 10
        nfreq = t2;
    end
    freq = tsx_seq_by(0, pi - pi / nfreq, pi / nfreq)';
end
order = max(1, min(t2, tsx_check_int(opts.order, "order")));
i = tsx_series_index(opts.series, names);
i = i(1);
v = tsx_mvar(y(:, i), 1:order, true);
ar = v.p(1:order, 1);
h = zeros(numel(freq), 1);
for k = 1:numel(freq)
    h(k) = 1 / abs(1 - sum(ar .* exp(-1i * freq(k) * (1:order)'))) ^ 2;
end
xlog = logical(opts.xlog(:)');
xlog = xlog(mod(0:1, numel(xlog)) + 1);
r = tsx_result("varspectrum", ...
    'call', struct('order', order, 'nfreq', nfreq, 'xlog', xlog, 'series', i), ...
    'series', names(i), 'ar', ar, 'sigma2', v.sigma(1, 1), ...
    'table', table(freq, v.sigma(1, 1) / (2 * pi) * h, 'VariableNames', {'freq', 'spectrum'}));
end
