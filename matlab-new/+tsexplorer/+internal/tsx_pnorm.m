function p = tsx_pnorm(x, lower_tail)
%TSX_PNORM Standard normal distribution function (stats::pnorm in R).
if nargin < 2 || lower_tail
    p = 0.5 * erfc(-x / sqrt(2));
else
    p = 0.5 * erfc(x / sqrt(2));
end
end
