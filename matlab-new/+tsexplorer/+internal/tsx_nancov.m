function c = tsx_nancov(y)
%TSX_NANCOV Covariance matrix with pairwise deletion of missing values.
if isvector(y)
    y = y(:);
end
y = y - mean(y, 1, 'omitnan');
[p, n] = tsexplorer.internal.tsx_nanprod(y', y);
c = p ./ (n - 1);
end
