function st = tsx_group_stats(z)
%TSX_GROUP_STATS Column statistics of a matrix (columns are the groups):
%   table with columns mean, median, p25, p75, min, max.
k = size(z, 2);
mx = nan(k, 1);
mn = nan(k, 1);
for j = 1:k
    v = z(~isnan(z(:, j)), j);
    if ~isempty(v)
        mn(j) = min(v);
        mx(j) = max(v);
    end
end
st = table(mean(z, 1, 'omitnan')', median(z, 1, 'omitnan')', ...
    tsexplorer.internal.tsx_prctile(z, 25)', tsexplorer.internal.tsx_prctile(z, 75)', mn, mx, ...
    'VariableNames', {'mean', 'median', 'p25', 'p75', 'min', 'max'});
end
