function out = tsx_names(m, names)
%TSX_NAMES Default and user supplied names of the series ("#1", "#2", ...).
%   A single string with blank-separated names is also accepted.
out = "#" + string(1:m);
if nargin < 2 || isempty(names)
    return
end
names = string(names);
names = names(:)';
if numel(names) == 1 && m > 1
    names = split(strtrim(names))';
end
k = min(numel(names), m);
for i = 1:k
    if ~ismissing(names(i)) && names(i) ~= ""
        out(i) = names(i);
    end
end
end
