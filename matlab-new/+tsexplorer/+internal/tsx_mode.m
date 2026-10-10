function v = tsx_mode(x)
%TSX_MODE Most frequent value (the smallest one in case of ties), as MATLAB
%   mode.
x = sort(x(~isnan(x)));
if isempty(x)
    v = NaN;
    return
end
% run lengths of the sorted values
starts = [1; find(diff(x(:)) ~= 0) + 1];
lens = diff([starts; numel(x) + 1]);
[~, k] = max(lens);
v = x(starts(k));
end
