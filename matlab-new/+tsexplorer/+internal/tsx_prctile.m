function out = tsx_prctile(y, p)
%TSX_PRCTILE Percentiles of each column (midpoint interpolation:
%   quantile(type = 5) inside the range of the data, clamped outside).
if isvector(y)
    y = y(:);
end
p = p(:);
out = nan(numel(p), size(y, 2));
for i = 1:size(y, 2)
    zi = sort(y(~isnan(y(:, i)), i));
    n = numel(zi);
    if n == 0
        continue
    end
    x = [0; 100 * ((1:n)' - 0.5) / n; 100];
    out(:, i) = interp1(x, [zi(1); zi; zi(n)], p);
end
end
