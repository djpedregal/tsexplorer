function out = tsx_text_vphillips(x, digits)
%TSX_TEXT_VPHILLIPS Text output of vphillips (print.tsx_vphillips in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
multi = numel(x.series) > 1;
mods = ["none", "const", "trend"];
titles = ["Phillips-Perron Tests (NO CONSTANT, NO TREND)", ...
    "Phillips-Perron Tests (CONSTANT, NO TREND)", "Phillips-Perron Tests (CONSTANT AND TREND)"];
out = strings(0, 1);
for k = 1:3
    d = x.(mods(k));
    notes = strings(0, 1);
    if mods(k) == "none"
        notes = ["Number of residual covs= " + x.call.ncovs; ...
            "PP-Test for z(t-1) is H0: Rho= 1 (Series is integrated)"; ...
            "P values are approximate based on tables"];
    end
    rn = [];
    if multi
        rn = d.series;
    end
    out = [out; tsx_cat_block(titles(k), notes, ...
        tsx_format_table(d(:, 2:end), [0, digits, digits, digits], rn, ...
            ["Lags", "z(t-1)", "PP-Test", "P-value"])); ""]; %#ok<AGROW>
end
end
