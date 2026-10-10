function p = tsx_pf(f, d1, d2, lower_tail)
%TSX_PF F distribution function (stats::pf in R).
if nargin < 4
    lower_tail = true;
end
f = f + zeros(size(d1));
d1 = d1 + zeros(size(f));
d2 = d2 + zeros(size(f));
p = nan(size(f));
ok = ~isnan(f);
pos = ok & f > 0;
if lower_tail
    p(pos) = betainc(d1(pos) .* f(pos) ./ (d1(pos) .* f(pos) + d2(pos)), d1(pos) / 2, d2(pos) / 2);
    p(ok & f <= 0) = 0;
else
    p(pos) = betainc(d2(pos) ./ (d2(pos) + d1(pos) .* f(pos)), d2(pos) / 2, d1(pos) / 2);
    p(ok & f <= 0) = 1;
end
end
