function out = tsx_text_sumstats(x, digits)
%TSX_TEXT_SUMSTATS Text output of sumstats (print.tsx_sumstats in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = x.call.digits;
end
if x.call.gaussian
    pm = "P(Mean= 0, Gaussian):";
else
    pm = "P(Mean= 0, Empirical):";
end
lab = ["Data points:", "Missing:", "Minimum:", "10% percentile:", "25% percentile:", ...
    "Mean:", pm, "Geometric Mean:", "Harmonic Mean:", "Median:", "Mode:", ...
    "75% percentile:", "90% percentile:", "Maximum:", "Interquartile Range:", "Range:", ...
    "Standard Deviation:", "Variance:", "Mean Absolute Deviation:", ...
    "Median Absolute Deviation:", "Mean/Standard Deviation:", "Skewness:", "Kurtosis (-3):"]';
vals = table2array(x.stats(:, 2:end))';
dig = repmat(digits, size(vals));
dig(1:2, :) = 0;
tab = strings(size(vals));
for i = 1:size(vals, 1)
    for j = 1:size(vals, 2)
        if isnan(vals(i, j))
            tab(i, j) = "NA";
        else
            tab(i, j) = sprintf('%.*f', dig(i, j), vals(i, j));
        end
    end
end
series = x.series(:)';
w = max(strlength([tab(:); series(:)]));
lw = max(strlength(lab));
head = pad("", lw) + " " + join(pad(series, w, 'left'), "  ");
body = strings(numel(lab), 1);
for i = 1:numel(lab)
    body(i) = pad(lab(i), lw) + " " + join(pad(tab(i, :), w, 'left'), "  ");
end
width = max(strlength([head; body]));
rule = string(repmat('-', 1, width));
out = [rule; head; rule; body(1:2); rule; body(3:14); rule; body(15:21); rule; ...
    body(22:23); rule];
if ~isempty(x.cor)
    cm = x.cor;
    marks = tsx_signif_marks(cm / x.se_cor);
    tabc = tsx_format_table(num2cell(cm, 1), digits, x.series, x.series);
    mk = [""; join(marks, "", 2)];
    out = [out; ""; "Correlation Matrix:"; tabc + "  |  " + mk];
end
end
