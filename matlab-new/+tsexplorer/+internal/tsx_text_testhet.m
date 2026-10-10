function out = tsx_text_testhet(x, digits)
%TSX_TEXT_TESTHET Text output of testhet (print.tsx_testhet in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
rule = string(repmat('-', 1, 50));
out = [rule; "Variance Ratio Tests"; rule; "H0: Variances are the same (homoskedasticity)."; ...
    "(Assumptions: Independence and Normality)"];
for s = x.series(:)'
    t = x.table(x.table.series == s, :);
    rn = "Samples (" + t.start1 + " - " + t.end1 + ") / (" + t.start2 + " - " + t.end2 + "):";
    out = [out; ""; tsx_cat_block("Series " + s + ":", [], ...
        tsx_format_table(t(:, {'f', 'p_value'}), digits, rn, ["F-Test", "P-value"]))]; %#ok<AGROW>
end
end
