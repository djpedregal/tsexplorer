function cc = tsx_forecast_cols(series, m, nf)
%TSX_FORECAST_COLS Columns of the forecasts and bands of one series.
f = 1:nf;
cc = struct('py', (f - 1) * m + series, ...
    'lower', (f - 1) * 2 * m + series, ...
    'upper', (f - 1) * 2 * m + m + series);
end
