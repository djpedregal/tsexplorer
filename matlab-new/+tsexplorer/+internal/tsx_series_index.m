function idx = tsx_series_index(series, names, allow_all)
%TSX_SERIES_INDEX Resolve a series selector (index or name) into column
%   indices. With ALLOW_ALL, "all" returns all the columns.
if nargin < 3
    allow_all = false;
end
m = numel(names);
if isempty(series)
    series = 1;
end
if ischar(series) || isstring(series) || iscellstr(series)
    series = string(series);
    if allow_all && numel(series) == 1 && lower(series) == "all"
        idx = 1:m;
        return
    end
    [found, idx] = ismember(series, names);
    if ~all(found)
        error('tsexplorer:series', "Series not found: %s", strjoin(series(~found), ", "));
    end
    idx = idx(:)';
    return
end
series = round(double(series(:)'));
if any(isnan(series)) || any(series < 1) || any(series > m)
    error('tsexplorer:series', "'series' must be between 1 and %d.", m);
end
idx = series;
end
