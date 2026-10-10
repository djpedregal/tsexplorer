function out = tsx_text_fcompare(x, digits)
%TSX_TEXT_FCOMPARE Text output of fcompare (print.tsx_fcompare in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
rule = string(repmat('-', 1, 60));
out = [rule; "Forecast Accuracy Comparison Tests"; rule; "Series: " + x.series; ...
    tsx_period_text(x.dates); rule; "H0: Forecasts have equal accuracy"; rule; ...
    "DM:   Diebold and Mariano (1995) Test"; "SIGN: Sign Test"; ...
    "Wi:   Wilcoxon Signed-Rank Test"; "Truncation value for DM test: " + x.call.trunc; ""];
losses = ["mse", "mae"];
titles = ["Table based on Squared Errors (MSE)", "Table based on Absolute Errors (MAE)"];
for k = 1:2
    t = x.table(x.table.loss == losses(k), :);
    out = [out; tsx_cat_block(titles(k), [], ...
        tsx_format_table(t(:, {'dm', 'p_dm', 'sign', 'p_sign', 'wilcoxon', 'p_wilcoxon'}), ...
            digits, "F#" + t.f1 + " vs F#" + t.f2 + ":", ["DM", "P", "SIGN", "P", "Wi", "P"])); ""]; %#ok<AGROW>
end
end
