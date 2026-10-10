function b = tsx_bds(x, maxdim, distance)
%TSX_BDS BDS statistic (Kanzler 1998) with epsilon = distance * sd(x).
%   Closeness indicators are processed one lag (diagonal) at a time.
%   Fields: w, p_value, c1, k.
x = x(:);
n = numel(x);
eps_ = distance * tsexplorer.internal.tsx_sd(x);
fullsum = ones(n, 1);        % 1 + number of neighbours of each point
pairs_from = zeros(maxdim, 1); % close pairs (i, j), i < j, with i >= m
cm = zeros(maxdim, 1);       % close m-histories
for d = 1:(n - 1)
    bb = abs(x(1:(n - d)) - x((1 + d):n)) <= eps_;
    fullsum(1:(n - d)) = fullsum(1:(n - d)) + bb;
    fullsum((1 + d):n) = fullsum((1 + d):n) + bb;
    for m = 1:maxdim
        if m <= n - d
            pairs_from(m) = pairs_from(m) + sum(bb(m:(n - d)));
        end
    end
    % a(t) = 1 if the m-histories ending at t and t + d are close:
    % a_m(t) = a_(m-1)(t) & b(t - m + 1), for t = m, ..., n - d
    len = n - d;
    a = bb;
    for m = 2:maxdim
        if m > len
            break
        end
        idx = (m:len)';
        a_new = false(len, 1);
        a_new(idx) = a(idx) & bb(idx - m + 1);
        a = a_new;
        cm(m) = cm(m) + sum(a(idx));
    end
end
npairs = @(k) k .* (k + 1) / 2;
c1 = pairs_from ./ npairs(n - (1:maxdim)');
bitsum1 = pairs_from(1);
k = (sum(fullsum .^ 2) + 2 * n - 3 * (2 * bitsum1 + n)) / n / (n - 1) / (n - 2);
w = zeros(maxdim - 1, 1);
for m = 2:maxdim
    cmm = cm(m) / npairs(n - m);
    j = (1:(m - 1))';
    sigma = 2 * sqrt(k ^ m + 2 * sum(k .^ (m - j) .* c1(1) .^ (2 * j)) + ...
        (m - 1) ^ 2 * c1(1) ^ (2 * m) - m ^ 2 * k * c1(1) ^ (2 * m - 2));
    w(m - 1) = sqrt(n - m + 1) * (cmm - c1(m) ^ m) / sigma;
end
pn = tsexplorer.internal.tsx_pnorm(w);
b = struct('w', w, 'p_value', 2 * min(pn, 1 - pn), 'c1', c1, 'k', k);
end
