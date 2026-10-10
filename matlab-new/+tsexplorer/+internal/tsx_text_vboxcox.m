function out = tsx_text_vboxcox(x, digits)
%TSX_TEXT_VBOXCOX Text output of vboxcox (print.tsx_vboxcox in R).
if isempty(digits)
    digits = 4;
end
if x.estimated
    title = "Estimation of Box-Cox Lambdas:";
else
    title = "Box-Cox Lambdas:";
end
out = tsexplorer.internal.tsx_cat_block(title, [], ...
    tsexplorer.internal.tsx_format_table({x.lambdas(:)}, digits, x.series, "Lambdas"));
end
