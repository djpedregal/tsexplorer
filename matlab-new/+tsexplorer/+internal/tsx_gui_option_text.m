function s = tsx_gui_option_text(op, value)
%TSX_GUI_OPTION_TEXT Text shown in a text box for the current value of an
%   option.
switch op.type
    case "text"
        s = strjoin(string(value), " ");
    case {"intvec", "numvec", "matrix"}
        s = tsexplorer.internal.tsx_format_numbers(value);
    otherwise
        s = string(value);
        if isempty(s)
            s = "";
        end
end
end
