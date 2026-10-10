function [prod, n] = tsx_nanprod(a, b)
%TSX_NANPROD Matrix product ignoring missing products. Returns the product
%   and the number of non missing terms of each element.
a0 = a;
b0 = b;
a0(isnan(a0)) = 0;
b0(isnan(b0)) = 0;
prod = a0 * b0;
n = double(~isnan(a)) * double(~isnan(b));
end
