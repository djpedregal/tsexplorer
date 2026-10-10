function s = tsx_format_dates(d)
%TSX_FORMAT_DATES Dates as text for the tables: "yyyy-MM" when all the dates
%   are first days of months at midnight, "yyyy-MM-dd" for other dates,
%   "yyyy-MM-dd HH:mm:ss" with times, numbers otherwise.
if isempty(d)
    s = strings(0, 1);
    return
end
if isdatetime(d)
    ok = ~isnat(d);
    tod = timeofday(d(ok));
    if any(tod ~= 0)
        fmt = 'yyyy-MM-dd HH:mm:ss';
    elseif all(day(d(ok)) == 1)
        fmt = 'yyyy-MM';
    else
        fmt = 'yyyy-MM-dd';
    end
    s = string(d, fmt);
    s(~ok) = "NA";
    return
end
s = string(d);
end
