function out = tsx_text_vident2(x, digits)
%TSX_TEXT_VIDENT2 Text output of vident2 (print.tsx_vident2 in R).
import tsexplorer.internal.*
m = numel(x.series);
if isempty(digits)
    digits = max(2, 7 - m);
end
if x.call.type == 1
    lab = "Partial Autoregression";
else
    lab = "Partial Lag Autocorrelation";
end
rule = string(repmat('-', 1, 60));
out = [rule; "Multivariate Sample Autocorrelation and " + lab + " Functions"; rule];
fmt = @(v) join(arrayfun(@(z) string(sprintf('%*.*f', digits + 4, digits, z)), v), " ");
for k = 0:x.call.ncoef
    if k > 0
        s = x.stats(k, :);
        out(end + 1, 1) = sprintf('k=%d AIC=%.4f SBC=%.4f Chi=%.4f P-Chi=%.4f P-QTest=%.4f |Sigma|=%s', ...
            k, s.aic, s.sbc, s.chi, s.p_chi, s.p_q, tsx_format_g(s.det_sigma, 4)); %#ok<AGROW>
    else
        out(end + 1, 1) = "k= 0"; %#ok<AGROW>
    end
    a = x.acf(:, :, k + 1);
    p = x.pacf(:, :, k + 1);
    ma = tsx_signif_marks(a ./ x.se_acf(:, :, k + 1));
    if k == 0
        mp = repmat(".", m, m);
    else
        rp = p ./ x.se_pacf(:, :, k + 1);
        rp(isnan(rp)) = 0;
        mp = tsx_signif_marks(rp);
    end
    for i = 1:m
        line = join(ma(i, :), "") + " | " + join(mp(i, :), "") + " | " + fmt(a(i, :));
        if k > 0
            line = line + " | " + fmt(p(i, :));
        end
        out(end + 1, 1) = line; %#ok<AGROW>
    end
    out(end + 1, 1) = ""; %#ok<AGROW>
end
end
