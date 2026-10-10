function r = fcompare(y, py, opts)
%FCOMPARE Forecast comparison tests.
%   For every pair of forecasts of one series, tests of the null hypothesis
%   of equal accuracy based on squared errors (MSE) and on absolute errors
%   (MAE): Diebold-Mariano (with trunc autocovariances in the long run
%   variance of the loss differential), sign test and Wilcoxon signed rank
%   test (exact for up to 15 non-zero differences, normal approximation
%   without continuity correction otherwise). An error with identifier
%   'tsexplorer:no_overlap' is raised when the actual values and the
%   forecasts do not overlap (see faccuracy).
%
%   R = fcompare(Y, PY)
%   R = fcompare(Y, PY, origin=0, trunc=1, series=1, names=[])
%
%   Arguments:
%     Y        Actual values (see faccuracy).
%     PY       Forecasts, at least two (see faccuracy).
%     origin   Forecast origin (see faccuracy).
%     trunc    Truncation lag of the long run variance of the
%              Diebold-Mariano test (number of autocovariances). Default 1.
%     series   Series to evaluate (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_fcompare" "tsx_result"] with fields call,
%     series, dates (dates of the forecasting sample for dated inputs,
%     otherwise []) and table, a table with one row per pair of forecasts
%     and loss function: f1, f2, loss ("mse" or "mae"), dm, p_dm, sign,
%     p_sign, wilcoxon (sum of the ranks of the positive differences) and
%     p_wilcoxon.
%
%   References:
%     Diebold, F.X. and Mariano, R.S. (1995). Comparing predictive
%     accuracy. Journal of Business and Economic Statistics, 13, 253-263.
%     Wilcoxon, F. (1945). Individual comparisons by ranking methods.
%     Biometrics Bulletin, 1, 80-83.
%
%   Examples:
%     y = log(load_data("airpas"));
%     tsexplorer.print(fcompare(y, [y(121:132), repmat(y(132), 12, 1)]))
%
%   See also tsexplorer.print, faccuracy, tsexplorer.fplot,
%   toolforecast.
arguments
    y
    py
    opts.origin = 0
    opts.trunc = 1
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
a = tsx_forecast_align(y, py, [], opts.origin, opts.names);
yy = a.y;
n = size(yy, 1);
m = size(yy, 2);
origin = a.origin;
s = tsx_series_index(opts.series, a.names);
s = s(1);
cols = tsx_forecast_cols(s, m, a.nf).py;
if numel(cols) < 2
    error('tsexplorer:fcompare', "At least two forecasts are needed.");
end
if origin >= n
    tsx_check_overlap(NaN, NaN);
end
tt = ((origin + 1):n)';
nofs = n - origin;
trunc = min(tsx_check_int(opts.trunc, "trunc", 0), nofs - 1);
actual = yy(tt, s);
tsx_check_overlap(actual, a.py(tt, cols));
e = a.py(tt, cols) - actual;
loss = struct('mse', e .^ 2, 'mae', abs(e));
tab = tsx_compare_losses(loss, trunc, nofs);
dates = [];
if ~isempty(a.dates)
    dates = a.dates(tt);
end
r = tsx_result("fcompare", 'call', struct('origin', origin, 'trunc', trunc, 'series', s), ...
    'series', a.names(s), 'table', tab, 'dates', dates);
end
