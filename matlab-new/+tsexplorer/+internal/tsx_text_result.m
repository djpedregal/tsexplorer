function out = tsx_text_result(r)
%TSX_TEXT_RESULT Default text output: the class and the fields of the result
%   with their sizes (print.tsx_result() in R shows the structure).
out = "<" + r.class(1) + ">";
fn = string(fieldnames(r))';
for f = fn(fn ~= "class")
    v = r.(f);
    sz = strjoin(string(size(v)), "x");
    out(end + 1, 1) = " $ " + f + ": " + class(v) + " [" + sz + "]"; %#ok<AGROW>
end
end
