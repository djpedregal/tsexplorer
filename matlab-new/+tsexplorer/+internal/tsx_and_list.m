function s = tsx_and_list(x)
%TSX_AND_LIST "a", "a and b", "a, b and c".
x = string(x);
if numel(x) == 1
    s = x;
    return
end
s = strjoin(x(1:end - 1), ", ") + " and " + x(end);
end
