function bands = tsx_forecast_bands(py, stdpy, m, level)
%TSX_FORECAST_BANDS Bands py -/+ z * stdpy, z = qnorm((1 + level) / 2), in
%   the internal layout (2 * n * m columns, see tsx_forecast_align).
if isempty(stdpy)
    bands = [];
    return
end
z = tsexplorer.internal.tsx_qnorm((1 + level) / 2);
bands = nan(size(py, 1), 2 * size(py, 2));
for f = 1:(size(py, 2) / m)
    pc = (f - 1) * m + (1:m);
    lc = (f - 1) * 2 * m + (1:m);
    bands(:, lc) = py(:, pc) - z * stdpy(:, pc);
    bands(:, lc + m) = py(:, pc) + z * stdpy(:, pc);
end
end
