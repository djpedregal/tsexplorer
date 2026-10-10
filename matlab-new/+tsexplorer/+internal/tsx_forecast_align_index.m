function a = tsx_forecast_align_index(y, py, stdpy, origin, names)
%TSX_FORECAST_ALIGN_INDEX Alignment by dates of timetables and tables with a
%   date column: the rows are the union of the dates of y, py and stdpy
%   (which must be of the same kind); every input is placed at the rows of
%   its dates, with missing values elsewhere. stdpy may be dated or a matrix
%   with the rows of py. When 'origin' is 0 it is set to the number of
%   dates before the first date of py.
import tsexplorer.internal.*
[yy, nms, dy] = as_tsx_matrix(y, names = names, trim = false);
[~, ~, dp] = tsx_input_parts(py);
pm = tsx_values_matrix(py);
if tsx_date_kind(dy) ~= tsx_date_kind(dp)
    error('tsexplorer:dates', "The dates of 'y' and 'py' are of different kinds (%s and %s).", ...
        tsx_date_kind(dy), tsx_date_kind(dp));
end
if numel(dp) ~= size(pm, 1)
    error('tsexplorer:dates', "The number of dates and of rows of 'py' differ.");
end
m = size(yy, 2);
mh = size(pm, 2);
tsx_check_py_cols(mh, m);
ds = [];
if ~isempty(stdpy)
    sm = tsx_values_matrix(stdpy);
    [~, ~, ds] = tsx_input_parts(stdpy);
    if isempty(ds)
        if size(sm, 1) ~= size(pm, 1)
            error('tsexplorer:dates', "'stdpy' must have dates or the same number of rows as 'py'.");
        end
        ds = dp;
    elseif tsx_date_kind(ds) ~= tsx_date_kind(dp)
        error('tsexplorer:dates', "The dates of 'py' and 'stdpy' are of different kinds.");
    end
end
if isempty(ds)
    all = unique([dy(:); dp(:)]);
else
    all = unique([dy(:); dp(:); ds(:)]);
end
place = @(x, d) place_rows(x, d, all);
yy = place(yy, dy);
pm2 = place(pm, dp);
if ~isempty(stdpy)
    stdpy = place(tsx_sd_cols(sm, mh), ds);
end
if isempty(origin) || origin == 0
    origin = sum(all < dp(1));
end
a = struct('y', yy, 'names', nms, 'py', pm2, 'stdpy', stdpy, 'origin', origin, ...
    'nf', mh / m, 'dates', all);
end

function out = place_rows(x, d, all)
out = nan(numel(all), size(x, 2));
[~, rows] = ismember(d, all);
out(rows, :) = x;
end
