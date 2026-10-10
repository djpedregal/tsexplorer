function yi = tsx_interpol(x, y, xi, limits)
%TSX_INTERPOL Linear interpolation in the grid (X, Y); linear extrapolation
%   from the two extreme points outside the grid; result clamped to LIMITS.
if isnan(xi) || any(isnan(x))
    yi = NaN;
    return
end
x = x(:);
y = y(:);
keep = [find(diff(x) ~= 0); numel(x)];
x = x(keep);
y = y(keep);
n = numel(x);
if xi < x(1)
    b = [1 x(1); 1 x(2)] \ y(1:2);
    yi = b(1) + b(2) * xi;
elseif xi > x(n)
    b = [1 x(n - 1); 1 x(n)] \ y((n - 1):n);
    yi = b(1) + b(2) * xi;
else
    yi = interp1(x, y, xi);
end
if nargin > 3 && ~isempty(limits)
    yi = min(max(yi, limits(1)), limits(2));
end
end
