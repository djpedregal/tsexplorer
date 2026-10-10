function [values, cn, dates, type] = tsx_input_parts(y)
%TSX_INPUT_PARTS Values, column names, dates and type of an input object.
%   TYPE is "timetable", "table" (with a datetime column) or "undated";
%   DATES is [] for "undated". Equivalent of tsx_input_parts() in R, where
%   ts, zoo, xts and data.frame objects are the dated inputs.
cn = [];
dates = [];
if istimetable(y)
    dates = tsexplorer.internal.tsx_check_dates(y.Properties.RowTimes);
    values = timetable2table(y, 'ConvertRowTimes', false);
    [values, cn] = table_values(values);
    type = "timetable";
    return
end
if istable(y)
    isdate = varfun(@(v) isdatetime(v), y, 'OutputFormat', 'uniform');
    if sum(isdate) > 1
        error('tsexplorer:input', "'y' has more than one date column.");
    end
    if sum(isdate) == 1
        dates = tsexplorer.internal.tsx_check_dates(y{:, isdate});
        [values, cn] = table_values(y(:, ~isdate));
        type = "table";
        return
    end
    [values, cn] = table_values(y);
    type = "undated";
    return
end
values = y;
type = "undated";
end

function [v, cn] = table_values(t)
ok = varfun(@(c) isnumeric(c) || islogical(c), t, 'OutputFormat', 'uniform');
if ~all(ok)
    error('tsexplorer:input', ...
        "All the columns of 'y' must be numeric (except one date column).");
end
cn = string(t.Properties.VariableNames);
v = double(t{:, :});
end
