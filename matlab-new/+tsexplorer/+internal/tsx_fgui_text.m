function out = tsx_fgui_text(tables, forecast)
%TSX_FGUI_TEXT Text of the tables of toolforecast (string column vector):
%   for one forecast the measures accumulated by horizon, for all of them
%   ("all") the summary table and the tests. TABLES is the output of
%   tsx_fgui_tables.
import tsexplorer.internal.*
if tables.no_overlap
    out = tsx_fgui_forecast_text(tables.forecasts, forecast);
    return
end
acc = tables.accuracy;
if isa(acc, 'MException')
    out = "Error: " + acc.message;
    return
end
if isstring(forecast) || ischar(forecast)
    out = tsexplorer.print(acc);
    cmp = tables.compare;
    if ~isempty(cmp)
        if isa(cmp, 'MException')
            out = [out; ""; "Error: " + cmp.message];
        else
            out = [out; ""; tsexplorer.print(cmp)];
        end
    end
    return
end
h = acc.by_horizon;
h = h(h.forecast == forecast, :);
h.forecast = [];
keep = true(1, width(h));
for j = 1:width(h)
    v = h{:, j};
    if isdatetime(v)
        keep(j) = ~all(isnat(v));
    elseif isnumeric(v)
        keep(j) = ~all(isnan(v));
    end
end
h = h(:, keep);
if ismember('date', h.Properties.VariableNames)
    h.date = tsx_format_dates(h.date);
end
out = tsx_cat_block( ...
    ["Forecasting Results"; "Series " + acc.series + ", Forecast #" + forecast; ...
     tsx_period_text(acc.dates)], ...
    "Measures accumulated up to each period", ...
    tsx_format_table(h, [0, repmat(3, 1, width(h) - 1)], [], ...
                     replace(string(h.Properties.VariableNames), "bias_mae", "bias+mae")));
end
