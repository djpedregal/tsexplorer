function s = tsx_series_label(series)
%TSX_SERIES_LABEL "a" or "a, b (VAR model)".
series = string(series);
if numel(series) > 1
    s = strjoin(series, ", ") + " (VAR model)";
else
    s = series;
end
end
