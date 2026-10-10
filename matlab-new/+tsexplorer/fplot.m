function r = fplot(y, py, opts)
%FPLOT Plot of actual values and forecasts.
%   Actual values of one series with one or all its forecasts, their
%   confidence bands and the forecast errors, optionally for a subperiod.
%   The returned struct holds the data to plot; tsexplorer.plot draws it.
%   (The name only shadows the function fplot inside the package; call it
%   as tsexplorer.fplot.)
%
%   R = tsexplorer.fplot(Y, PY)
%   R = tsexplorer.fplot(Y, PY, stdpy=[], origin=0, series=1, forecast=1,
%                        s=12, subsample=0, level=0.95, names=[])
%
%   Arguments:
%     Y          Actual values (see faccuracy).
%     PY         Forecasts (see faccuracy).
%     stdpy      Optional standard deviations of the forecasts (see
%                faccuracy).
%     origin     Forecast origin (see faccuracy).
%     series     Series to plot (index or name).
%     forecast   Forecast to plot (1..n) or "all".
%     s          Length of the subperiods for the navigation (default 12).
%     subsample  0 for the full sample or k for the k-th subperiod of
%                length s.
%     level      Confidence level of the bands (default 0.95).
%     names      Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_fplot" "tsx_result"] with fields call,
%     series, time, actual, forecasts (matrix), lower, upper (matrices of
%     bands PY -/+ z * stdpy, or [] without stdpy), errors (forecast minus
%     actual for one forecast, absolute errors for all), origin and dates
%     (date of each row for dated inputs, otherwise []).
%
%   Examples:
%     y = log(load_data("airpas"));
%     p = tsexplorer.fplot(y, [y(121:132), repmat(y(132), 12, 1)], forecast="all");
%     tsexplorer.plot(p)
%     % dated forecasts after the end of the data (aligned by their dates)
%     [a, ~, d] = load_data("airpas");
%     yd = timetable(d, log(a));
%     fut = timetable(datetime(1961, 1:12, 1)', repmat(log(a(144)), 12, 1));
%     tsexplorer.plot(tsexplorer.fplot(yd, fut, s=24, subsample=6))
%     % with 90% intervals (standard deviations growing with the horizon)
%     tsexplorer.plot(tsexplorer.fplot(yd, fut, stdpy=0.03 * sqrt(1:12)', ...
%         level=0.9, s=24, subsample=6))
%
%   See also tsexplorer.plot, faccuracy, fcompare,
%   toolforecast.
arguments
    y
    py
    opts.stdpy = []
    opts.origin = 0
    opts.series = 1
    opts.forecast = 1
    opts.s = 12
    opts.subsample = 0
    opts.level = 0.95
    opts.names = []
end
import tsexplorer.internal.*
a = tsx_forecast_align(y, py, opts.stdpy, opts.origin, opts.names, opts.level);
yy = a.y;
n = size(yy, 1);
m = size(yy, 2);
si = tsx_series_index(opts.series, a.names);
si = si(1);
cc = tsx_forecast_cols(si, m, a.nf);
forecast = opts.forecast;
all = (ischar(forecast) || isstring(forecast)) && lower(string(forecast)) == "all";
if all
    fsel = 1:a.nf;
else
    f = round(double(forecast));
    if isempty(f) || isnan(f) || f < 1 || f > a.nf
        error('tsexplorer:forecast', "Invalid 'forecast'.");
    end
    fsel = f;
end
s = min(tsx_check_int(opts.s, "s"), n);
nsub = ceil(n / s);
subsample = min(max(0, round(opts.subsample)), nsub);
if subsample == 0
    t = (1:n)';
else
    t = (((subsample - 1) * s + 1):min(subsample * s, n))';
end
fc = a.py(:, cc.py(fsel));
lo_band = [];
up_band = [];
if ~isempty(a.bands)
    lo_band = a.bands(:, cc.lower(fsel));
    up_band = a.bands(:, cc.upper(fsel));
end
if all
    err = abs(yy(:, si) - fc);
    fcall = "all";
else
    err = fc - yy(:, si);
    fcall = fsel;
end
r = tsx_result("fplot", 'call', struct('series', si, 'forecast', fcall, 's', s, ...
    'subsample', subsample, 'n_subsamples', nsub, 'level', opts.level), ...
    'series', a.names(si), 'time', t, 'actual', yy(:, si), 'forecasts', fc, ...
    'lower', lo_band, 'upper', up_band, 'errors', err, 'origin', a.origin, 'dates', a.dates);
end
