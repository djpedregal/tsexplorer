function out = tsx_fgui_forecast_text(p, forecast)
%TSX_FGUI_FORECAST_TEXT Text of toolforecast when there are no actual values
%   in the forecasting period (out of sample forecasts): the table of the
%   forecasts, without actual values nor error measures. P is the fplot
%   result of all the forecasts of the series. For one forecast the table has
%   the forecast and, with standard deviations, the bounds of its intervals;
%   for all of them ("all"), the forecasts side by side.
import tsexplorer.internal.*
if ~isstruct(p)
    out = "No actual values in the forecasting period: no accuracy measures.";
    if isa(p, 'MException')
        out = [out; "Error: " + p.message];
    end
    return
end
fc = p.forecasts;
tt = (1:size(fc, 1))';
tt = tt(tt > p.origin & sum(~isnan(fc), 2) > 0);
all = isstring(forecast) || ischar(forecast);
if all
    k = 1:size(fc, 2);
else
    k = forecast;
end
cols = {tt};
cn = "t";
if ~isempty(p.dates)
    cols{end + 1} = tsx_format_dates(p.dates(tt));
    cn(end + 1) = "date";
end
ntxt = numel(cols);
if all
    for j = k
        cols{end + 1} = fc(tt, j); %#ok<AGROW>
        cn(end + 1) = "F#" + j; %#ok<AGROW>
    end
else
    cols{end + 1} = fc(tt, k);
    cn(end + 1) = "fcst";
    if ~isempty(p.lower)
        cols = [cols, {p.lower(tt, k), p.upper(tt, k)}];
        cn = [cn, "lower", "upper"];
    end
end
nnum = numel(cols) - ntxt;
notes = "No actual values in the forecasting period: forecasts only";
if ~all && ~isempty(p.lower)
    notes = [notes; "lower, upper: bounds of the " + sprintf('%g', 100 * p.call.level) + ...
        "% prediction intervals"];
end
if all
    sub = "Series " + p.series + ", all forecasts";
else
    sub = "Series " + p.series + ", Forecast #" + k;
end
if isempty(p.dates)
    period = tsx_period_text([]);
else
    period = tsx_period_text(p.dates(tt));
end
out = tsx_cat_block(["Forecasting Results"; sub; period], notes, ...
    tsx_format_table(cols, [zeros(1, ntxt), repmat(3, 1, nnum)], [], cn));
end
