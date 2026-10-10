function x = tsx_qnorm(p)
%TSX_QNORM Standard normal quantile function (stats::qnorm in R).
x = -sqrt(2) * erfcinv(2 * p);
end
