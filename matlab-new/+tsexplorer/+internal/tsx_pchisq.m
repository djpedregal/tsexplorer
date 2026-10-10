function p = tsx_pchisq(q, df, lower_tail)
%TSX_PCHISQ Chi-squared distribution function (stats::pchisq in R).
if nargin < 3
    lower_tail = true;
end
q = q + zeros(size(df));
df = df + zeros(size(q));
p = nan(size(q));
ok = ~isnan(q) & ~isnan(df);
pos = ok & q > 0;
if lower_tail
    p(pos) = gammainc(q(pos) / 2, df(pos) / 2, 'lower');
    p(ok & q <= 0) = 0;
else
    p(pos) = gammainc(q(pos) / 2, df(pos) / 2, 'upper');
    p(ok & q <= 0) = 1;
end
end
