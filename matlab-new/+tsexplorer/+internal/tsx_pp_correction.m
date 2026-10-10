function z = tsx_pp_correction(tstat, e, sse, s2, se_rho, n, ncovs)
%TSX_PP_CORRECTION Phillips-Perron correction of the t statistic.
%   nw: long run variance (Bartlett window); g0: residual variance (both
%   divided by the full sample size T).
nw = sse;
ne = numel(e);
for k = 1:ncovs
    if k >= ne
        break
    end
    nw = nw + 2 * (1 - k / (ncovs + 1)) * sum(e(1:(ne - k)) .* e((k + 1):ne));
end
nw = nw / n;
g0 = sse / n;
z = sqrt(g0 / nw) * tstat - 0.5 * (nw - g0) / sqrt(nw) * n * se_rho / sqrt(s2);
end
