function k = tsx_kurtosis(x)
%TSX_KURTOSIS Kurtosis (biased version, divisor T; not in excess).
x = x(~isnan(x));
d = x - mean(x);
k = mean(d .^ 4) / mean(d .^ 2) ^ 2;
end
