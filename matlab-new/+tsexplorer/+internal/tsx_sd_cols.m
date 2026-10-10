function sm = tsx_sd_cols(sm, mh)
%TSX_SD_COLS Standard deviations of the forecasts: MH columns, the layout of
%   py (missing ones filled with NaN).
if size(sm, 2) > mh
    error('tsexplorer:stdpy', ...
        "'stdpy' must have at most as many columns as 'py' (the standard deviations of the forecasts), not %d.", ...
        size(sm, 2));
end
if any(sm(:) < 0)
    error('tsexplorer:stdpy', "'stdpy' must contain standard deviations (non negative values).");
end
if size(sm, 2) < mh
    sm = [sm, nan(size(sm, 1), mh - size(sm, 2))];
end
end
