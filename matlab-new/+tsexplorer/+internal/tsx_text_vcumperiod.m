function out = tsx_text_vcumperiod(x, digits)
%TSX_TEXT_VCUMPERIOD Text output of vcumperiod (print.tsx_vcumperiod in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block("Series " + x.series + ": Cumulative Periodogram", ...
    sprintf('Band half width: 1%% %.4f; 5%% %.4f', x.bands.p01, x.bands.p05), ...
    tsexplorer.internal.tsx_format_table(x.table, digits, [], ["Frequency", "Cum. Power"]));
end
