function out = tsx_cat_block(title, notes, table)
%TSX_CAT_BLOCK Block of text lines: title lines, notes and a ruled table
%   (string column vector), with rules of the width of the longest line (at
%   least 40). Same layout as tsx_cat_block() in R, which prints it.
if nargin < 1, title = strings(0, 1); end
if nargin < 2, notes = strings(0, 1); end
if nargin < 3, table = strings(0, 1); end
title = string(title);
notes = string(notes);
table = string(table);
title = title(:);
notes = notes(:);
table = table(:);
width = max([strlength([title; notes; table; ""]); 40]);
rule = string(repmat('-', 1, width));
out = rule;
if ~isempty(title)
    out = [out; title; rule];
end
if ~isempty(notes)
    out = [out; notes; rule];
end
if ~isempty(table)
    out = [out; table(1); rule; table(2:end); rule];
end
end
