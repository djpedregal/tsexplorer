function z = tsx_boxcox(z, lambda)
%TSX_BOXCOX Box-Cox transformation with parameter LAMBDA.
if lambda == 0
    z = log(z);
else
    z = (z .^ lambda - 1) / lambda;
end
end
