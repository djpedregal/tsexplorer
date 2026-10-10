function out = tsx_text_johansentest(x, digits)
%TSX_TEXT_JOHANSENTEST Text output of johansentest (print.tsx_johansentest in
%   R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
t = x.table;
multi = numel(x.series) > 1;
if multi
    hh = "h= " + t.h0 + "  -  h= " + t.h1;
else
    hh = "Lags " + t.lag;
end
lines = tsx_format_table(t(:, {'stat_none', 'p_none', 'stat_const', 'p_const', 'stat_trend', ...
    'p_trend'}), digits, hh, ["Stat1", "P-value", "Stat2", "P-value", "Stat3", "P-value"]);
title = "Johansen Cointegration Tests";
notes = strings(0, 1);
if multi
    title = title + " (lags= " + strjoin(string(unique(t.lag, 'stable')), ", ") + ")";
    notes = "'h' is the number of cointegrated relations";
end
notes = [notes; "Stat1: test statistic based on model without deterministic parts"; ...
    "Stat2: test statistic based on model including a constant term"; ...
    "Stat3: test statistic based on model including a constant and linear trend"; ...
    "Critical values are approximate based on tables"; ...
    "(no tables available for Stat3: P-values are NA)"];
out = tsx_cat_block(title, notes, lines);
if multi
    out = [out; ""; tsx_cat_block([], [], tsx_format_table(x.eigen(:, 2:end), ...
        [0, repmat(digits, 1, 6)], [], ["i", "Eigen1", "-T[1-l(i)]", "Eigen2", "-T[1-l(i)]", ...
        "Eigen3", "-T[1-l(i)]"]))];
end
end
