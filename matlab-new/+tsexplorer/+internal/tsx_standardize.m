function z = tsx_standardize(y)
%TSX_STANDARDIZE Standardisation of each column (mean 0, standard deviation
%   1, computed with T - 1). Zero standard deviations are replaced by one.
if isvector(y)
    y = y(:);
end
mz = mean(y, 1, 'omitnan');
sz = tsexplorer.internal.tsx_sd(y);
sz(~isnan(sz) & sz == 0) = 1;
z = (y - mz) ./ sz;
end
