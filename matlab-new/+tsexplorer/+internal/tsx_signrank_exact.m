function p = tsx_signrank_exact(v, w)
%TSX_SIGNRANK_EXACT Probability of the smaller tail of the signed rank
%   statistic by counting subsets of ranks.
n = numel(v);
v = sort(v(:));
maxw = n * (n + 1) / 2;
if w > maxw / 2
    w = maxw - w;
end
if any(v ~= floor(v))
    v = round(2 * v);
    w = round(2 * w);
end
w = floor(w);
cnt = zeros(w + 1, 1);
cnt(1) = 1;
top = 1;
for vj = v(v <= w)'
    newtop = min(top + vj, w + 1);
    first = min(vj, w + 1) + 1;
    if first <= newtop
        hi = (first:newtop)';
    else
        hi = zeros(0, 1);
    end
    lo = (1:numel(hi))';
    cnt(hi) = cnt(hi) + cnt(lo);
    top = newtop;
end
p = sum(cnt) / 2 ^ n;
end
