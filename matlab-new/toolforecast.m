function app = toolforecast(y, py, opts)
%TOOLFORECAST Interactive forecasting tool.
%   Graphical interface for the evaluation of forecasts: plot of actual
%   values and forecasts with confidence bands (computed from the standard
%   deviations of the forecasts) and forecast errors, navigation by
%   subperiods, and tables of accuracy measures (faccuracy) and
%   comparison tests (fcompare). When the forecasts do not
%   overlap the actual values (e.g. true out-of-sample forecasts) the table
%   shows only the forecasts (and the bounds of their intervals), without
%   actual values nor accuracy measures.
%
%   toolforecast(Y, PY)
%   toolforecast(Y, PY, stdpy=[], origin=0, names=[], level=0.95,
%                           visible=true)
%   APP = toolforecast(...)
%
%   Arguments:
%     Y        Actual values (see faccuracy).
%     PY       Forecasts (see faccuracy).
%     stdpy    Optional standard deviations of the forecasts (see
%              faccuracy).
%     origin   Forecast origin (see faccuracy).
%     names    Optional names of the series.
%     level    Confidence level of the prediction intervals computed from
%              stdpy (default 0.95), used in the plot and in the interval
%              measures of faccuracy. It can also be changed in
%              the Options of the interface.
%     visible  false creates the windows without showing them (for tests).
%
%   Details:
%     The actual values and the forecasts must be of the same type, without
%     dates or with dates (timetables, or tables with a datetime column;
%     see faccuracy); otherwise an error is raised. With dates,
%     the plots show them on the time axis and the tables include them.
%
%     The interface is a window (uifigure) with the menus Series, Forecasts
%     (#1, ..., #n, All) and Options... (length of the subperiods,
%     truncation lag of the Diebold-Mariano test, confidence level), the
%     navigation buttons <<< subperiod >>> (0 = full sample) and the
%     tables, with the plot in a graphics window (figure) to its right. Its
%     text and graphics windows are independent of those of
%     tooltest: a new call reuses them and brings them to the
%     front. Closing the text window closes both.
%
%   Value:
%     APP      Struct with the windows (fig, and graphics(), a function
%              that returns the graphics figure), state(), a function that
%              returns the state of the interface (series, forecast, s,
%              subsample, trunc, level, last_call, result and tables),
%              widgets(), and actions: functions that do what the widgets
%              do (set_series, set_forecast, prev, nxt, set_nav,
%              set_options, options_dialog, close).
%
%   Examples:
%     y = log(load_data("airpas"));
%     py = [y(121:132), repmat(y(132), 12, 1)];
%     toolforecast(y, py)
%     % with 90% intervals of the first forecast (its standard deviations)
%     toolforecast(y, py, stdpy=repmat(0.05, 12, 1), level=0.9)
%     % with dates (actual values and forecasts of the same type)
%     d = datetime(1949, 1:144, 1)';
%     toolforecast(timetable(d, y), timetable(d(133:144), py))
%
%   See also faccuracy, fcompare, tsexplorer.fplot,
%   tooltest.
arguments
    y
    py
    opts.stdpy = []
    opts.origin = 0
    opts.names = []
    opts.level = 0.95
    opts.visible = true
end
import tsexplorer.internal.*
tsx_check_level(opts.level);
a = tsx_forecast_align(y, py, opts.stdpy, opts.origin, opts.names);
r = tsx_ui_toolforecast(y, py, opts.stdpy, opts.origin, opts.names, a, opts.level, ...
    logical(opts.visible));
if nargout > 0
    app = r;
end
end
