function r = faccuracy(y, py, opts)
%FACCURACY Forecast accuracy measures.
%   Error measures of one or several forecasts of one series over the
%   forecasting period (observations after origin), and measures of the
%   uncertainty of their prediction intervals when stdpy is given.
%
%   R = faccuracy(Y, PY)
%   R = faccuracy(Y, PY, stdpy=[], origin=0, series=1,
%                            level=0.95, names=[])
%
%   Arguments:
%     Y        Actual values (see as_tsx_matrix); it may include
%              the in-sample period.
%     PY       Forecasts: a matrix with n * m columns, being m the number
%              of series in Y and n the number of forecasts; forecast f of
%              series s is in column (f - 1) * m + s. Y and PY must be of
%              the same type (an error is raised otherwise): both without
%              dates (vectors, matrices or numeric tables; aligned at the
%              end), or both timetables or both tables with a datetime
%              column (aligned by their dates).
%     stdpy    Optional standard deviations of the forecasts, with the
%              layout of PY (the standard deviation of forecast f of series
%              s is in column (f - 1) * m + s; missing columns at the end
%              are taken as not available). The prediction intervals are
%              PY -/+ z * stdpy, with z the (1 + level) / 2 quantile of the
%              standard normal distribution. With dated inputs it may be of
%              the same type as PY or have no dates and the rows of PY.
%     origin   Forecast origin: number of in-sample observations. If Y is
%              longer than PY, it is set to size(Y, 1) - size(PY, 1). With
%              dated inputs and origin = 0, it is the number of periods
%              before the first date of PY (counted from the earliest date
%              of Y and PY).
%     series   Series to evaluate (index or name).
%     level    Confidence level of the prediction intervals computed from
%              stdpy (default 0.95); the significance level is
%              alpha = 1 - level.
%     names    Optional names of the series.
%
%   Details:
%     Point forecast measures, with e_t = F_t - y_t:
%     * Bias and MAE: mean error and mean absolute error.
%     * Bias+MAE: |Bias| + MAE.
%     * RMSE: root mean squared error.
%     * MASE: MAE relative to the in-sample MAE of the one step naive
%       forecast (only when origin > 0).
%
%     Interval measures (only with stdpy), with alpha = 1 - level and the
%     bounds of the Gaussian prediction intervals l_t = F_t - z sigma_t and
%     u_t = F_t + z sigma_t, being sigma_t the standard deviation of the
%     forecast (stdpy) and z the 1 - alpha / 2 quantile of the standard
%     normal distribution (1.96 for level = 0.95):
%     * Coverage: proportion of actual values inside [l_t, u_t] (to be
%       compared with level).
%     * Range: mean width u_t - l_t.
%     * MIS (mean interval score): mean of (u_t - l_t) +
%       2 / alpha (l_t - y_t) 1(y_t < l_t) + 2 / alpha (y_t - u_t) 1(y_t > u_t).
%     * Pinball loss of the lower bound (quantile tau = alpha / 2) and of
%       the upper bound (tau = 1 - alpha / 2): mean of tau (y_t - q_t) if
%       y_t >= q_t and (1 - tau) (q_t - y_t) otherwise.
%
%     If no period after origin has both an actual value and a forecast
%     (the forecasts do not overlap the actual values), an error with
%     identifier 'tsexplorer:no_overlap' is raised. The same applies to
%     fcompare; tsexplorer.fplot plots these data without
%     problems.
%
%   Value:
%     A struct of class ["tsx_faccuracy" "tsx_result"] with fields call,
%     series, table (table, one row per forecast, with columns forecast, n,
%     bias, mae, bias_mae, rmse, mase, coverage, range, mis, pinball_lower
%     and pinball_upper; the interval measures are NaN without stdpy),
%     by_horizon (table with the same measures accumulated up to each
%     period of the forecasting sample, with columns forecast, t, date
%     (only for dated inputs), actual, fcst, e and the measures) and dates
%     (dates of the forecasting sample for dated inputs, otherwise []).
%
%   References:
%     Hyndman, R.J. and Koehler, A.B. (2006). Another look at measures of
%     forecast accuracy. International Journal of Forecasting, 22,
%     679-688.
%     Gneiting, T. and Raftery, A.E. (2007). Strictly proper scoring rules,
%     prediction, and estimation. Journal of the American Statistical
%     Association, 102, 359-378.
%     Svetunkov, I. (2023). Forecasting and Analytics with the Augmented
%     Dynamic Adaptive Model (ADAM). Chapman and Hall/CRC.
%     https://openforecast.org/adam/
%
%   Examples:
%     % data without dates (forecasts aligned with the end of y)
%     y = log(load_data("airpas"));
%     f1 = y(121:132);             % naive seasonal forecast
%     f2 = repmat(y(132), 12, 1);  % naive forecast
%     tsexplorer.print(faccuracy(y, [f1 f2]))
%     % with 95% intervals of the first forecast (standard deviation 0.05)
%     tsexplorer.print(faccuracy(y, f1, stdpy=repmat(0.05, 12, 1)))
%     % data with dates (both of the same type), aligned by their dates
%     d = datetime(1949, 1:144, 1)';
%     yd = timetable(d, y);
%     fd = timetable(d(133:144), f1, f2);
%     tsexplorer.print(faccuracy(yd, fd))
%
%   See also tsexplorer.print, fcompare, tsexplorer.fplot,
%   toolforecast.
arguments
    y
    py
    opts.stdpy = []
    opts.origin = 0
    opts.series = 1
    opts.level = 0.95
    opts.names = []
end
import tsexplorer.internal.*
level = tsx_check_level(opts.level);
alpha = 1 - level;
a = tsx_forecast_align(y, py, opts.stdpy, opts.origin, opts.names, level);
yy = a.y;
n = size(yy, 1);
m = size(yy, 2);
origin = a.origin;
s = tsx_series_index(opts.series, a.names);
s = s(1);
cc = tsx_forecast_cols(s, m, a.nf);
cols = cc.py;
if origin >= n
    tsx_check_overlap(NaN, NaN);
end
tt = ((origin + 1):n)';
actual = yy(tt, s);
tsx_check_overlap(actual, a.py(tt, cols));
if origin > 0
    zin = yy(1:origin, s);
    maseden = mean(abs(diff(zin)), 'omitnan');
else
    zin = [];
    maseden = NaN;
end
ind = ~isnan(actual);
tindx = sum(ind);
if any(ind)
    ti = cumsum(ind);
else
    ti = ones(size(ind));
end
nh = numel(tt);
na_h = nan(nh, 1);
% pinball loss (NaN where the bound or the actual value are missing)
pinball = @(q, tau) (actual >= q) .* tau .* (actual - q) + ...
    (actual < q) .* (1 - tau) .* (q - actual);
tab = table();
hor = table();
for f = 1:numel(cols)
    fc = a.py(tt, cols(f));
    e = fc - actual;
    [cover, width, score, pb_l, pb_u] = deal(na_h);
    if ~isempty(a.bands)
        lo = a.bands(tt, cc.lower(f));
        up = a.bands(tt, cc.upper(f));
        okb = ~isnan(actual) & ~isnan(lo) & ~isnan(up);
        lo(~okb) = NaN;
        up(~okb) = NaN;
        cover = double(actual >= lo & actual <= up);
        cover(~okb) = NaN;
        width = up - lo;
        score = width + 2 / alpha * (lo - actual) .* (actual < lo) + ...
            2 / alpha * (actual - up) .* (actual > up);
        pb_l = pinball(lo, alpha / 2);
        pb_u = pinball(up, 1 - alpha / 2);
    end
    bias = sum(e, 'omitnan') / tindx;
    mae = sum(abs(e), 'omitnan') / tindx;
    bias_h = tsx_nancumsum(e) ./ ti;
    mae_h = tsx_nancumsum(abs(e)) ./ ti;
    if isempty(zin)
        mase = NaN;
        mase_h = na_h;
    else
        mase = sum(abs(e) / maseden, 'omitnan') / tindx;
        mase_h = tsx_nancumsum(abs(e) / maseden) ./ ti;
    end
    tab = [tab; table(f, tindx, bias, mae, abs(bias) + mae, ...
        sqrt(sum(e .^ 2, 'omitnan') / tindx), mase, mean_ok(cover), mean_ok(width), ...
        mean_ok(score), mean_ok(pb_l), mean_ok(pb_u), ...
        'VariableNames', {'forecast', 'n', 'bias', 'mae', 'bias_mae', 'rmse', 'mase', ...
                          'coverage', 'range', 'mis', 'pinball_lower', 'pinball_upper'})]; %#ok<AGROW>
    hor = [hor; table(repmat(f, nh, 1), tt, actual, fc, e, bias_h, mae_h, abs(bias_h) + mae_h, ...
        sqrt(tsx_nancumsum(e .^ 2) ./ ti), mase_h, cummean_ok(cover), cummean_ok(width), ...
        cummean_ok(score), cummean_ok(pb_l), cummean_ok(pb_u), ...
        'VariableNames', {'forecast', 't', 'actual', 'fcst', 'e', 'bias', 'mae', 'bias_mae', ...
                          'rmse', 'mase', 'coverage', 'range', 'mis', 'pinball_lower', ...
                          'pinball_upper'})]; %#ok<AGROW>
end
dates = [];
if ~isempty(a.dates)
    hor = addvars(hor, a.dates(hor.t), 'After', 't', 'NewVariableNames', 'date');
    dates = a.dates(tt);
end
r = tsx_result("faccuracy", 'call', struct('origin', origin, 'series', s, 'level', level), ...
    'series', a.names(s), 'table', tab, 'by_horizon', hor, 'dates', dates);
end

% mean and cumulative mean over the non missing values of x
function v = mean_ok(x)
if any(~isnan(x))
    v = mean(x, 'omitnan');
else
    v = NaN;
end
end

function out = cummean_ok(x)
k = cumsum(~isnan(x));
out = tsexplorer.internal.tsx_nancumsum(x) ./ k;
out(k == 0) = NaN;
end
