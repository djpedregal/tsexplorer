function r = tsx_ols(y, x)
%TSX_OLS Ordinary least squares returning what the tests of the package need
%   (fields beta, ixx, e, sse).
ixx = inv(x' * x);
beta = ixx * (x' * y);
e = y - x * beta;
r = struct('beta', beta, 'ixx', ixx, 'e', e, 'sse', sum(e .^ 2));
end
