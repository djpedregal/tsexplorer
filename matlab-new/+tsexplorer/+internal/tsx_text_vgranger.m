function out = tsx_text_vgranger(x, digits)
%TSX_TEXT_VGRANGER Text output of vgranger (print.tsx_vgranger in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
lags = x.call.lags;
if max(lags) == numel(lags)
    const = "";
else
    const = "CONSTRAINED ";
end
t = x.table;
out = tsx_cat_block(["Granger Causality Tests"; ...
    "Based on a " + const + "VAR(" + max(lags) + ") model"], [], ...
    tsx_format_table(t(:, {'constraints', 'f', 'p_f', 'chi2', 'p_chi2'}), ...
        [0, repmat(digits, 1, 4)], t.h0, ...
        ["Constraints", "F-Stat", "P-value", "Chi-stat", "P-value"]));
end
