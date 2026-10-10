function a = tsx_forecast_align_rows(y, py, stdpy, origin, names)
%TSX_FORECAST_ALIGN_ROWS Alignment by position of data without dates: series
%   of different lengths are aligned at the end (padding with missing values
%   at the beginning); when y is longer than py the forecast origin is
%   T - nrow(py).
import tsexplorer.internal.*
[y, nms] = as_tsx_matrix(y, names = names, trim = false);
py = tsx_values_matrix(py);
n = size(y, 1);
m = size(y, 2);
nh = size(py, 1);
mh = size(py, 2);
tsx_check_py_cols(mh, m);
if ~isempty(stdpy)
    stdpy = tsx_sd_cols(tsx_values_matrix(stdpy), mh);
end
if isempty(origin)
    origin = 0;
end
if nh > n
    y = [y; nan(nh - n, m)];
end
n = size(y, 1);
pp = max([size(stdpy, 1), nh, n]);
pad = @(x) [nan(pp - size(x, 1), size(x, 2)); x];
if n > nh
    origin = n - nh;
end
y = pad(y);
py = pad(py);
if ~isempty(stdpy)
    stdpy = pad(stdpy);
end
a = struct('y', y, 'names', nms, 'py', py, 'stdpy', stdpy, 'origin', origin, ...
    'nf', mh / m, 'dates', []);
end
