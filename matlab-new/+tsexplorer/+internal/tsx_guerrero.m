function c = tsx_guerrero(lambda, z, group)
%TSX_GUERRERO Guerrero (1993) criterion (coefficient of variation).
z = z(:);
n = numel(z);
ny = floor(n / group);
yr = reshape(z((n - ny * group + 1):n), group, ny);
myr = mean(yr, 1, 'omitnan');
sd = tsexplorer.internal.tsx_sd(yr);
yt = sd ./ myr .^ (1 - lambda);
c = tsexplorer.internal.tsx_sd(yt(:)) / mean(yt, 'omitnan');
end
