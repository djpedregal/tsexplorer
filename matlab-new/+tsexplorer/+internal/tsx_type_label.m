function s = tsx_type_label(type)
%TSX_TYPE_LABEL Description of an input type for the error messages.
switch type
    case "undated"
        s = "data without dates";
    case "timetable"
        s = "a timetable";
    case "table"
        s = "a table with dates";
    otherwise
        s = type;
end
end
