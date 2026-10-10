function d = tsx_lilliefors_stat(x)
%TSX_LILLIEFORS_STAT Kolmogorov-Smirnov statistic against a normal with
%   estimated mean and standard deviation: max(D+, D-).
x = sort(x(:));
n = numel(x);
f = tsexplorer.internal.tsx_pnorm((x - mean(x)) / tsexplorer.internal.tsx_sd(x));
i = (1:n)';
d = max(max(i / n - f), max(f - (i - 1) / n));
end
