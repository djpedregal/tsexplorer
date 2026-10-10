function out = tsx_text_vscatter(x, digits)
%TSX_TEXT_VSCATTER Text output of vscatter (print.tsx_vscatter in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block("Least squares lines (y = intercept + slope * x)", [], ...
    tsexplorer.internal.tsx_format_table(x.coef, digits, [], ["x", "y", "Intercept", "Slope"]));
end
