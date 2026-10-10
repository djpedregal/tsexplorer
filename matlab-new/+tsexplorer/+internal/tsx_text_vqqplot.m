function out = tsx_text_vqqplot(x, digits)
%TSX_TEXT_VQQPLOT Text output of vqqplot (print.tsx_vqqplot in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block("Series " + x.series + ": QQ plot", [], ...
    tsexplorer.internal.tsx_format_table(x.table, digits, [], ["Theoretical", "Empirical"]));
end
