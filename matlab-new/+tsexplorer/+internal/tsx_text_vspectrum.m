function out = tsx_text_vspectrum(x, digits)
%TSX_TEXT_VSPECTRUM Text output of vspectrum (print.tsx_vspectrum in R).
if isempty(digits)
    digits = 4;
end
out = tsexplorer.internal.tsx_cat_block(tsx_vspectrum_title(x), [], ...
    tsexplorer.internal.tsx_format_table(x.table, digits));
end

function title = tsx_vspectrum_title(x)
if numel(x.series) == 1
    if x.call.smooth > 1
        kind = "Smoothed Spectrum, Triangular window (" + x.call.smooth + ")";
    else
        kind = "Periodogram";
    end
    title = "Series " + x.series + ": " + kind;
else
    title = "Cross spectrum: " + x.series(1) + " - " + x.series(2);
end
end
