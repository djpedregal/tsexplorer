function r = tsx_result(fun, varargin)
%TSX_RESULT Constructor of the result objects of the package.
%   R = TSX_RESULT(FUN, NAME1, VALUE1, ...) returns a struct whose first
%   field, 'class', is ["tsx_<fun>" "tsx_result"] (the S3 class of the R
%   version), followed by the given fields in the same order.
r = struct();
r.class = ["tsx_" + string(fun), "tsx_result"];
for k = 1:2:numel(varargin)
    r.(varargin{k}) = varargin{k + 1};
end
end
