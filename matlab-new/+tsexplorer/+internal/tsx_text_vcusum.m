function out = tsx_text_vcusum(x, digits)
%TSX_TEXT_VCUSUM Text output of vcusum (print.tsx_vcusum in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
tab = x.table;
if ~isempty(x.dates)
    tab = addvars(tab, tsx_format_dates(x.dates), 'After', 't', 'NewVariableNames', 'date');
end
out = tsx_cat_block("Series " + x.series + ": CUSUM and CUSUMSQ tests", [], ...
    tsx_format_table(tab, [0, repmat(digits, 1, width(tab) - 1)]));
end
