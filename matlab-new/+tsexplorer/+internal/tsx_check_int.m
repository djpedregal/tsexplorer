function x = tsx_check_int(x, name, minval)
%TSX_CHECK_INT Check a single integer option (>= MINVAL, default 1).
if nargin < 3
    minval = 1;
end
if ~isnumeric(x) || numel(x) ~= 1 || isnan(x) || x < minval
    error('tsexplorer:option', "'%s' must be a single number >= %g.", name, minval);
end
x = round(double(x));
end
