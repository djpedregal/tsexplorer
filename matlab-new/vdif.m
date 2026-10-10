function out = vdif(y, order, s)
%VDIF Differencing of a vector of time series.
%   Applies multiplicative difference operators prod_j (1 - B^s_j)^d_j to
%   each series.
%
%   Z = vdif(Y)
%   Z = vdif(Y, ORDER, S)
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     ORDER    Difference orders (default 1). A vector applies the same
%              multiplicative polynomials to every series; a matrix with
%              one row per series allows different orders for each series
%              (the last row is recycled).
%     S        Seasonal period of each polynomial (default 1; same layout
%              as ORDER).
%
%   Value:
%     Matrix of differenced data. The first r observations are lost, being
%     r the largest total order of differencing among the series.
%
%   Examples:
%     y = log(load_data("airpas"));
%     z = vdif(y, [1 1], [1 12]);
%     z(1:6)
%     z2 = vdif([y y], [1 0; 1 1], [1 12]);
%     z2(1:6, :)
%
%   See also as_tsx_matrix.
arguments
    y
    order = 1
    s = 1
end
import tsexplorer.internal.*
y = as_tsx_matrix(y, trim = false);
n = size(y, 1);
m = size(y, 2);
order = tsx_rows_as_series(order, m);
s = tsx_rows_as_series(s, m);
if size(s, 2) < size(order, 2)
    s = [s, ones(m, size(order, 2) - size(s, 2))];
end
polys = cell(1, m);
la = 0;
for i = 1:m
    a = 1;
    for j = 1:size(order, 2)
        for k = 1:order(i, j)
            if s(i, j) > 0
                a = tsx_conv(a, [1, zeros(1, s(i, j) - 1), -1]);
            end
        end
    end
    polys{i} = a;
    la = max(la, numel(a));
end
if la > n
    error('tsexplorer:vdif', "Not enough data for the required differences.");
end
out = nan(n - la + 1, m);
rows = (la:n)';
for i = 1:m
    a = polys{i};
    acc = 0;
    for k = 1:numel(a)
        acc = acc + a(k) * y(rows - k + 1, i);
    end
    out(:, i) = acc;
end
end
