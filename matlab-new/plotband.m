function r = plotband(y, opts)
%PLOTBAND Time series plot with confidence bands.
%   Plot of one series with its mean and mean +/- 2 standard deviations, of
%   a subsample of length s, of all the subsamples of length s overlaid, or
%   of all the series together (optionally standardised).
%
%   R = plotband(Y)
%   R = plotband(Y, s=12, standard=false, fixed=true, series=1,
%                           subsample=0, overlay=false, names=[])
%
%   Arguments:
%     Y          Time series data (see as_tsx_matrix).
%     s          Length of the subsamples (seasonal period). Default 12.
%     standard   For series = "all", plot the standardised series.
%     fixed      Keep the vertical scale of the full sample when plotting a
%                subsample.
%     series     One series (index or name) or "all".
%     subsample  0 for the full sample, k for the k-th subsample of length
%                s (observations (k - 1) * s + 1 to k * s).
%     overlay    For one series, plot all the subsamples of length s
%                overlaid (one line per subsample).
%     names      Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_plotband" "tsx_result"] with fields call,
%     series, data (the data to plot: a matrix whose rows are the time
%     indices time), time, dates (dates of time for dated inputs, []
%     otherwise or with overlay), mean, sd, ylim and n_subsamples.
%
%   Examples:
%     [y, ~, d] = load_data("airpas");
%     tsexplorer.plot(plotband(timetable(d, y)))
%     tsexplorer.plot(plotband(y, overlay=true))
%     tsexplorer.plot(plotband(load_data("scc"), ...
%         series="all", standard=true))
%
%   See also tsexplorer.plot, vboxplot, vtboxplot.
arguments
    y
    opts.s = 12
    opts.standard (1, 1) logical = false
    opts.fixed (1, 1) logical = true
    opts.series = 1
    opts.subsample = 0
    opts.overlay (1, 1) logical = false
    opts.names = []
end
import tsexplorer.internal.*
[y, names, dates] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
s = min(tsx_check_int(opts.s, "s"), n);
nsub = ceil(n / s);
subsample = min(max(0, round(opts.subsample)), nsub);
series = opts.series;
idx = tsx_series_index(series, names, true);
all_series = numel(idx) > 1 || ((ischar(series) || isstring(series)) && ...
    lower(string(series(1))) == "all");
if subsample == 0
    t = (1:n)';
else
    t = (((subsample - 1) * s + 1):min(subsample * s, n))';
end
if ~all_series
    z = y(:, idx);
    zm = mean(z, 'omitnan');
    zs = tsx_sd(z);
    if opts.overlay
        dat = reshape([z; nan(nsub * s - n, 1)], s, nsub);
        t = (1:s)';
        ylim = [min([zm - 2 * zs; dat(:)], [], 'omitnan'), max([zm + 2 * zs; dat(:)], [], 'omitnan')];
    else
        dat = z(t);
        if opts.fixed
            ref = z;
        else
            ref = z(t);
        end
        ylim = [min([zm - 2 * zs; ref], [], 'omitnan'), max([zm + 2 * zs; ref], [], 'omitnan')];
    end
else
    z = y(:, idx);
    if opts.standard
        z = tsx_standardize(z);
        zm = 0;
        zs = 1;
    else
        zm = NaN;
        zs = NaN;
    end
    dat = z(t, :);
    if opts.fixed
        ylim = [min(z(:), [], 'omitnan'), max(z(:), [], 'omitnan')];
    else
        ylim = [min(dat(:), [], 'omitnan'), max(dat(:), [], 'omitnan')];
    end
end
if ylim(1) == ylim(2)
    ylim = ylim + [-1, 1];
end
pdates = [];
if ~isempty(dates) && (all_series || ~opts.overlay)
    pdates = dates(t);
end
r = tsx_result("plotband", ...
    'call', struct('s', s, 'standard', opts.standard, 'fixed', opts.fixed, 'series', idx, ...
                   'subsample', subsample, 'overlay', opts.overlay, 'all', all_series), ...
    'series', names(idx), 'data', dat, 'time', t, 'dates', pdates, 'mean', zm, 'sd', zs, ...
    'ylim', ylim, 'n_subsamples', nsub);
end
