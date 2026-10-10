function out = tsx_text_vhist(x, digits)
%TSX_TEXT_VHIST Text output of vhist (print.tsx_vhist in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block("Series " + x.series + ": Histogram", [], ...
    tsexplorer.internal.tsx_format_table(x.hist, [digits, digits, digits, 0]));
end
