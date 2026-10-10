function s = tsx_format_numbers(x)
%TSX_FORMAT_NUMBERS Text of a numeric vector or matrix for a text box
%   ("1:10", "-1:0.1:1", "1 2 12", "1 30; 50 90").
if isempty(x)
    s = "";
    return
end
if ~isvector(x)
    s = strjoin(arrayfun(@(i) strjoin(string(x(i, :)), " "), 1:size(x, 1)), "; ");
    return
end
x = x(:)';
d = diff(x);
if numel(x) > 2 && all(d == 1)
    s = x(1) + ":" + x(end);
elseif numel(x) > 2 && all(abs(d - d(1)) < 1e-9)
    s = x(1) + ":" + string(sprintf('%.6g', d(1))) + ":" + x(end);
else
    s = strjoin(string(x), " ");
end
end
