function a = tsx_forecast_align(y, py, stdpy, origin, names, level)
%TSX_FORECAST_ALIGN Alignment of actual values, forecasts and standard
%   deviations of the forecasts. Returns a struct with fields y, names, py,
%   stdpy (matrices with the same number of rows; stdpy [] if not given),
%   bands ([] without stdpy), origin, nf (number of forecasts) and dates
%   (date of each row, [] when the inputs have no dates).
%
%   Layout of the inputs:
%     y      T x m matrix of actual values.
%     py     forecasts, n * m columns: forecast f of series s is column
%            (f - 1) * m + s.
%     stdpy  standard deviations of the forecasts, with the layout of py.
%   The bands are py -/+ z * stdpy, z = qnorm((1 + level) / 2), kept in a
%   matrix with 2 * n * m columns: lower band of forecast f of series s in
%   column (f - 1) * 2 * m + s and the upper band in (f - 1) * 2 * m + m + s.
%   y and py must be of the same type: both without dates (aligned by
%   position, at the end), both timetables or both tables with a datetime
%   column (aligned by their dates).
import tsexplorer.internal.*
if nargin < 6
    level = 0.95;
end
tsx_check_level(level);
[~, ~, ~, type_y] = tsx_input_parts(y);
[~, ~, ~, type_p] = tsx_input_parts(py);
if type_y ~= type_p
    error('tsexplorer:type', "'y' and 'py' must be of the same type (%s and %s given).", ...
        tsx_type_label(type_y), tsx_type_label(type_p));
end
if ~isempty(stdpy)
    [~, ~, ~, type_s] = tsx_input_parts(stdpy);
    if ~ismember(type_s, [type_p, "undated"])
        error('tsexplorer:type', ...
            "'stdpy' must be of the same type as 'py' or have no dates (%s given).", ...
            tsx_type_label(type_s));
    end
end
if type_y == "undated"
    a = tsx_forecast_align_rows(y, py, stdpy, origin, names);
else
    a = tsx_forecast_align_index(y, py, stdpy, origin, names);
end
a.bands = tsx_forecast_bands(a.py, a.stdpy, size(a.y, 2), level);
end
