function p = tsx_pgamma(x, shape, scale, lower_tail)
%TSX_PGAMMA Gamma distribution function (stats::pgamma in R).
if nargin < 4
    lower_tail = true;
end
x = x + zeros(size(shape));
shape = shape + zeros(size(x));
scale = scale + zeros(size(x));
p = nan(size(x));
ok = ~isnan(x);
pos = ok & x > 0;
if lower_tail
    p(pos) = gammainc(x(pos) ./ scale(pos), shape(pos), 'lower');
    p(ok & x <= 0) = 0;
else
    p(pos) = gammainc(x(pos) ./ scale(pos), shape(pos), 'upper');
    p(ok & x <= 0) = 1;
end
end
