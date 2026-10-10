function p = tsx_pt(t, df)
%TSX_PT Student t distribution function, lower tail (stats::pt in R).
t = t + zeros(size(df));
df = df + zeros(size(t));
tail = 0.5 * betainc(df ./ (df + t .^ 2), df / 2, 0.5);
p = tail;
p(t > 0) = 1 - tail(t > 0);
p(isnan(t)) = NaN;
end
