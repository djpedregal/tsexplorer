function out = tsx_text_varspectrum(x, digits)
%TSX_TEXT_VARSPECTRUM Text output of varspectrum (print.tsx_varspectrum in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block( ...
    "Series " + x.series + ": AR Spectrum(" + x.call.order + ")", [], ...
    tsexplorer.internal.tsx_format_table(x.table, digits, [], ["Frequency", "Power"]));
end
