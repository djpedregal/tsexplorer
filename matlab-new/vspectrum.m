function r = vspectrum(y, opts)
%VSPECTRUM Spectrum, cross spectrum, gains and coherence.
%   Periodogram of one series, smoothed with a triangular window of length
%   smooth, or, for two series, the gains and squared coherence computed
%   from the smoothed cross periodogram. The periodogram is
%   |sum_t z_t exp(-i w t)|^2 / (2 pi T) at the Fourier frequencies; near
%   the frequencies 0 and pi the smoothing window uses the symmetry of the
%   periodogram.
%
%   R = vspectrum(Y)
%   R = vspectrum(Y, smooth=1, xlog=[false true], series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     smooth   Length of the triangular smoothing window (an even value is
%              increased by one; 1 means no smoothing). Default 1.
%     xlog     Logical vector of length 2: logarithmic scale for the
%              frequency (period) axis and for the power axis in the plot.
%              Default [false true].
%     series   One series (index or name) or two series for the cross
%              spectrum.
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_vspectrum" "tsx_result"] with fields call,
%     series and table, a table with column freq (radians, from 0 to pi)
%     and
%     * one series: periodogram and spectrum (smoothed),
%     * two series: cross_amplitude (modulus of the smoothed cross
%       spectrum), spectrum1, spectrum2 (smoothed), gain12 (cross amplitude
%       over the spectrum of the first series), gain21 and coherence
%       (squared coherence).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vspectrum(vdif(log(y)), smooth=5))
%     lp = load_data("lydia_pinkham");
%     tsexplorer.plot(vspectrum(vdif(log(lp)), smooth=7, ...
%         series=[1 2]))
%
%   See also tsexplorer.plot, varspectrum, vcumperiod.
arguments
    y
    opts.smooth = 1
    opts.xlog = [false, true]
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
smooth = max(1, min(floor(n / 2), tsx_check_int(opts.smooth, "smooth")));
if mod(smooth, 2) == 0
    smooth = smooth + 1;
end
idx = tsx_series_index(opts.series, names);
if numel(idx) > 2
    idx = idx(1:2);
end
[ii, w] = tsx_mspectrum(y(:, idx));
even = mod(n, 2) == 0;
if numel(idx) == 1 || idx(1) == idx(2)
    per = real(squeeze(ii(1, 1, :)));
    tab = table(w, per, real(tsx_smooth_triangular(per, smooth, even)), ...
        'VariableNames', {'freq', 'periodogram', 'spectrum'});
    idx = idx(1);
else
    a = abs(tsx_smooth_triangular(squeeze(ii(1, 2, :)), smooth, even));
    s1 = real(tsx_smooth_triangular(squeeze(ii(1, 1, :)), smooth, even));
    s2 = real(tsx_smooth_triangular(squeeze(ii(2, 2, :)), smooth, even));
    tab = table(w, a, s1, s2, a ./ s1, a ./ s2, a .^ 2 ./ (s1 .* s2), ...
        'VariableNames', {'freq', 'cross_amplitude', 'spectrum1', 'spectrum2', 'gain12', ...
                          'gain21', 'coherence'});
end
xlog = logical(opts.xlog(:)');
xlog = xlog(mod(0:1, numel(xlog)) + 1);
r = tsx_result("vspectrum", 'call', struct('smooth', smooth, 'xlog', xlog, 'series', idx), ...
    'series', names(idx), 'table', tab);
end
