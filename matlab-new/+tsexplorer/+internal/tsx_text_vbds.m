function out = tsx_text_vbds(x, digits)
%TSX_TEXT_VBDS Text output of vbds (print.tsx_vbds in R).
if isempty(digits)
    digits = 4;
end
rn = [];
if numel(x.series) > 1
    rn = x.table.series;
end
out = tsexplorer.internal.tsx_cat_block("Brock, Dechert & Scheinkman (BDS) Test", ...
    ["H0: Process is linear and i.i.d."; ...
     "Distance as a fraction of the S.D.: " + tsexplorer.internal.tsx_format_num(x.call.distance)], ...
    tsexplorer.internal.tsx_format_table(x.table(:, {'dim', 'w', 'p_value'}), [0, digits, digits], ...
        rn, ["Dim", "BDS", "P-value"]));
end
