function tsx_check_overlap(actual, fc)
%TSX_CHECK_OVERLAP Error when no period after the origin has both an actual
%   value and a forecast of the series. The error identifier is
%   'tsexplorer:no_overlap' (class "tsx_no_overlap" in R), so that the GUI
%   can show the plot without tables.
both = ~isnan(actual(:)) & sum(~isnan(fc), 2) > 0;
if ~any(both)
    error('tsexplorer:no_overlap', ...
        "The actual values and the forecasts do not overlap: no accuracy measures can be computed.");
end
end
