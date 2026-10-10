function out = tsx_text_varsbc2(x, digits)
%TSX_TEXT_VARSBC2 Text output of varsbc2 (print.tsx_varsbc2 in R).
if isempty(digits)
    digits = 4;
end
if x.linear
    kind = "Linear";
else
    kind = "Non-Linear";
end
out = tsexplorer.internal.tsx_cat_block( ...
    ["SBC Criterion of Squared Data"; "Series " + x.series], ...
    "Minimum at lag " + x.best + ": Process is " + kind, ...
    tsexplorer.internal.tsx_format_table(x.table, [0, digits], [], ["Lag", "SBC"]));
end
