function x = tsx_rows_as_series(x, m)
%TSX_ROWS_AS_SERIES Expand a vector/matrix of per-series options to M rows
%   (last row recycled). A vector is one row.
if isvector(x)
    x = x(:)';
end
if size(x, 1) < m
    x = [x; repmat(x(end, :), m - size(x, 1), 1)];
end
x = x(1:m, :);
end
