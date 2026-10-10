function out = tsx_text_vboxplot(x, digits)
%TSX_TEXT_VBOXPLOT Text output of vboxplot (print.tsx_vboxplot in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = 4;
end
st = x.stats;
if ~isempty(x.group_dates)
    st = addvars(st, tsx_format_dates(x.group_dates), 'After', 'group', 'NewVariableNames', 'start');
end
out = tsx_cat_block("Series " + x.series + ": Box Plot (every " + x.call.s + " samples apart)", ...
    [], tsx_format_table(st, [0, repmat(digits, 1, width(st) - 1)]));
end
