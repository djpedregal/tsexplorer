function [y, idx] = tsx_remove_nan(y)
%TSX_REMOVE_NAN Remove rows with all the series missing at the beginning and
%   end of the sample. IDX are the rows retained ([] if nothing removed).
allna = all(isnan(y), 2);
idx = [];
if ~any(allna)
    return
end
ok = find(~allna);
if isempty(ok)
    y = y([], :);
    return
end
idx = (ok(1):ok(end))';
y = y(idx, :);
end
