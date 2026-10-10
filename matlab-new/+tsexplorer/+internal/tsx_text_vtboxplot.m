function out = tsx_text_vtboxplot(x, digits)
%TSX_TEXT_VTBOXPLOT Text output of vtboxplot (print.tsx_vtboxplot in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block("Series " + x.series + ": Transpose Box Plot (" + ...
    x.call.s + " samples, standardised)", [], ...
    tsexplorer.internal.tsx_format_table(x.stats, [0, repmat(digits, 1, 6)]));
end
