function s = tsx_period_text(dates)
%TSX_PERIOD_TEXT "Forecasting period: first to last" (empty without dates).
if isempty(dates)
    s = strings(0, 1);
    return
end
d = tsexplorer.internal.tsx_format_dates(dates);
s = "Forecasting period: " + d(1) + " to " + d(end);
end
