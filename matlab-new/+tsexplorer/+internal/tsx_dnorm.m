function d = tsx_dnorm(x)
%TSX_DNORM Standard normal density (stats::dnorm in R).
d = exp(-x .^ 2 / 2) / sqrt(2 * pi);
end
