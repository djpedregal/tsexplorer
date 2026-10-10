function out = tsx_text_vtsay(x, digits)
%TSX_TEXT_VTSAY Text output of vtsay (print.tsx_vtsay in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
out = tsx_cat_block(["Tsay(1986) Non-Linear Test"; "H0: Process is linear"], ...
    "Summary table based on an AR(" + x.call.lags + ") Model:", ...
    tsx_format_table(x.table(:, 2:end), [digits, 0, 0, digits], x.series, ...
        ["Tsay-F", "DoF1", "DoF2", "P-value"]));
out = [out; ""; "Auxiliary Regressions:"];
for s = x.series(:)'
    r = x.regressions(x.regressions.series == s, :);
    out = [out; tsx_cat_block("Series: " + s, [], ...
        tsx_format_table(r(:, {'beta', 't', 'p_value'}), digits, r.variable, ...
            ["Betas", "T", "P-value"]))]; %#ok<AGROW>
end
end
