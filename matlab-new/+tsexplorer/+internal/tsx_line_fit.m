function b = tsx_line_fit(x, y)
%TSX_LINE_FIT Least squares line of Y on X (missing values handled with
%   tsx_nanprod). Returns [intercept, slope].
import tsexplorer.internal.*
x = x(:);
y = y(:);
xm = [ones(numel(x), 1), x];
if any(isnan(x)) || any(isnan(y))
    b = inv(tsx_nanprod(xm', xm)) * tsx_nanprod(xm', y);
else
    b = xm \ y;
end
b = b(:)';
end
