function s = tsx_sd(x)
%TSX_SD Standard deviation (divisor n - 1) of each column ignoring missing
%   values, NaN with fewer than two values (stats::sd(x, na.rm = TRUE) in R).
if isvector(x)
    x = x(:);
end
s = nan(1, size(x, 2));
for j = 1:size(x, 2)
    v = x(~isnan(x(:, j)), j);
    if numel(v) > 1
        s(j) = sqrt(sum((v - mean(v)) .^ 2) / (numel(v) - 1));
    end
end
end
