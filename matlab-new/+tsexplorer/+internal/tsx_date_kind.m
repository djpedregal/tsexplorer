function k = tsx_date_kind(d)
%TSX_DATE_KIND Kind of a vector of dates ("datetime" or "numeric").
if isdatetime(d)
    k = "datetime";
else
    k = "numeric";
end
end
