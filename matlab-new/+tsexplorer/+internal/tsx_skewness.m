function s = tsx_skewness(x)
%TSX_SKEWNESS Skewness (biased version, divisor T).
x = x(~isnan(x));
d = x - mean(x);
s = mean(d .^ 3) / mean(d .^ 2) ^ 1.5;
end
