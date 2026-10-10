function d = tsx_check_dates(d)
%TSX_CHECK_DATES Check a vector of dates: datetime (or numeric), increasing
%   and without repetitions or missing values.
d = d(:);
if isdatetime(d)
    bad = any(isnat(d)) || any(diff(d) <= 0);
elseif isnumeric(d)
    d = double(d);
    bad = any(isnan(d)) || any(diff(d) <= 0);
else
    error('tsexplorer:dates', "Unsupported type of dates: %s.", class(d));
end
if bad
    error('tsexplorer:dates', ...
        "The dates must be increasing, without repetitions or missing values.");
end
end
