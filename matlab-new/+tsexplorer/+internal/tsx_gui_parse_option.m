function v = tsx_gui_parse_option(op, value)
%TSX_GUI_PARSE_OPTION Convert the value typed or selected in the GUI into the
%   value of an option (text boxes are parsed with tsx_parse_numbers; no
%   code is evaluated).
import tsexplorer.internal.*
switch op.type
    case "int"
        v = round(to_number(value));
        check_number(op, v);
    case "num"
        v = to_number(value);
        check_number(op, v);
    case "logical"
        v = logical(value);
        v = v(1);
    case "logical2"
        v = logical(value(:)');
        v = v(mod(0:1, numel(v)) + 1);
    case "select"
        v = to_number(value);
    case "text"
        value = strjoin(string(value), " ");
        if strtrim(value) == ""
            v = [];
        else
            v = value;
        end
    case "intvec"
        v = round(tsx_parse_numbers(value));
    case "numvec"
        v = tsx_parse_numbers(value);
    case "matrix"
        v = tsx_parse_numbers(value, true);
end
end

function v = to_number(value)
if isnumeric(value)
    v = double(value);
else
    v = str2double(string(value));
end
end

function check_number(op, v)
if numel(v) ~= 1 || isnan(v)
    error('tsexplorer:option', "%s: a number is expected.", op.label);
end
if ~isempty(op.min) && v < op.min
    error('tsexplorer:option', "%s: the minimum is %g.", op.label, op.min);
end
if ~isempty(op.max) && v > op.max
    error('tsexplorer:option', "%s: the maximum is %g.", op.label, op.max);
end
end
