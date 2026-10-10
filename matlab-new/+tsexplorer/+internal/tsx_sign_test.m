function out = tsx_sign_test(d, nofs)
%TSX_SIGN_TEST Sign test (normal approximation).
if all(~isnan(d) & d == 0)
    out = [0, 1];
    return
end
n1 = sum(d > 0);
stat = (n1 - 0.5 * nofs) / (0.5 * sqrt(nofs));
out = [stat, 2 * tsexplorer.internal.tsx_pnorm(abs(stat), false)];
end
