function lines = tsx_format_table(x, digits, row_names, col_names)
%TSX_FORMAT_TABLE Format columns as a text table (string column vector: the
%   header line and one line per row). X is a table or a cell array of
%   column vectors (numeric or text); DIGITS are the decimals of each column
%   (recycled); NaN is printed as "NA". Columns are right-aligned and
%   separated by two blanks; ROW_NAMES (optional) are left-aligned before
%   them. Same layout as tsx_format_table() in R.
if nargin < 2 || isempty(digits)
    digits = 4;
end
if nargin < 3
    row_names = [];
end
if istable(x)
    if nargin < 4 || isempty(col_names)
        col_names = string(x.Properties.VariableNames);
    end
    cols = cell(1, width(x));
    for j = 1:width(x)
        cols{j} = x{:, j};
    end
else
    cols = x;
    if nargin < 4 || isempty(col_names)
        col_names = "V" + string(1:numel(cols));
    end
end
col_names = string(col_names);
ncol = numel(cols);
digits = digits(mod(0:(ncol - 1), numel(digits)) + 1);
nrow = numel(cols{1});
txt = cell(1, ncol);
widths = zeros(1, ncol);
for j = 1:ncol
    v = cols{j};
    v = v(:);
    if isnumeric(v) || islogical(v)
        v = double(v);
        s = strings(nrow, 1);
        for i = 1:nrow
            if isnan(v(i))
                s(i) = "NA";
            elseif isinf(v(i))
                if v(i) > 0
                    s(i) = "Inf";
                else
                    s(i) = "-Inf";
                end
            else
                s(i) = sprintf('%.*f', digits(j), v(i));
            end
        end
    else
        s = string(v);
    end
    txt{j} = s;
    widths(j) = max(strlength([col_names(j); s]));
end
head = join(arrayfun(@(j) pad(col_names(j), widths(j), 'left'), 1:ncol), "  ");
body = strings(nrow, 1);
for i = 1:nrow
    body(i) = join(arrayfun(@(j) pad(txt{j}(i), widths(j), 'left'), 1:ncol), "  ");
end
lines = [head; body];
if ~isempty(row_names)
    row_names = string(row_names(:));
    rw = max(strlength(row_names));
    rn = [pad("", rw); pad(row_names, rw, 'right')];
    lines = rn + "  " + lines;
end
end
