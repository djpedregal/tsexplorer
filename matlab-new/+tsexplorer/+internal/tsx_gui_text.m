function out = tsx_gui_text(result, err)
%TSX_GUI_TEXT Text output of a tool (what tsexplorer.print shows), as a
%   string column vector; RESULT may be an MException. ERR (optional) is an
%   error of the options shown before the output.
out = strings(0, 1);
if nargin > 1 && ~isempty(err)
    out = ["Error in options: " + err; ""];
end
if isa(result, 'MException')
    out = [out; "Error: " + result.message];
    return
end
out = [out; tsexplorer.print(result)];
end
