function a = tsx_adf_ols(y, x)
%TSX_ADF_OLS OLS of an ADF regression. Fields: beta, cov, se, e, sse, s2.
if size(x, 1) <= size(x, 2)
    error('tsexplorer:lags', "Too many lags for the sample size; reduce 'lags'.");
end
r = tsexplorer.internal.tsx_ols(y, x);
s2 = r.sse / (size(x, 1) - size(x, 2));
cov = s2 * r.ixx;
a = struct('beta', r.beta(:), 'cov', cov, 'se', sqrt(diag(cov)), 'e', r.e(:), ...
    'sse', r.sse, 's2', s2);
end
