function v = tsx_parse_numbers(txt, as_matrix)
%TSX_PARSE_NUMBERS Parse a numeric vector or matrix written in a text box:
%   "1:10", "1 2 12", "[1, 3]", "-1:0.1:1", "1 30; 50 90". No code is
%   evaluated. Returns [] for an empty text.
if nargin < 2
    as_matrix = false;
end
txt = regexprep(string(txt), "c\(|\)|\[|\]", " ");
txt = regexprep(txt, "\s*:\s*", ":");
rows = split(txt, ";");
vals = {};
for r = rows(:)'
    tok = split(strtrim(r), regexpPattern("[\s,]+"));
    tok = tok(tok ~= "");
    out = [];
    for tk = tok(:)'
        parts = str2double(split(tk, ":"));
        if any(isnan(parts))
            error('tsexplorer:option', "Invalid number: %s", tk);
        end
        if numel(parts) == 1
            out = [out, parts]; %#ok<AGROW>
        elseif numel(parts) == 2
            out = [out, parts(1):parts(2)]; %#ok<AGROW>
        else
            out = [out, tsexplorer.internal.tsx_seq_by(parts(1), parts(3), parts(2))]; %#ok<AGROW>
        end
    end
    if ~isempty(out)
        vals{end + 1} = out; %#ok<AGROW>
    end
end
if isempty(vals)
    v = [];
elseif as_matrix && numel(vals) > 1
    v = vertcat(vals{:});
else
    v = [vals{:}];
end
end
