function tb = tsx_fgui_tables(y, py, stdpy, origin, series, trunc, level, names, nf)
%TSX_FGUI_TABLES Tables of toolforecast: accuracy measures of every forecast
%   (faccuracy) and, with two or more forecasts, the comparison
%   tests (fcompare). Struct with fields accuracy, compare (results
%   or MExceptions; compare is [] with one forecast), no_overlap and
%   forecasts. When the actual values and the forecasts do not overlap there
%   are no accuracy tables (accuracy = [], no_overlap = true) and 'forecasts'
%   is the fplot result of all the forecasts, for the table of the forecasts
%   only.
tb = struct('accuracy', [], 'compare', [], 'no_overlap', false, 'forecasts', []);
try
    acc = faccuracy(y, py, stdpy = stdpy, origin = origin, series = series, ...
        level = level, names = names);
catch err
    acc = err;
end
if isa(acc, 'MException') && acc.identifier == "tsexplorer:no_overlap"
    try
        fc = tsexplorer.fplot(y, py, stdpy = stdpy, origin = origin, series = series, ...
            forecast = "all", level = level, names = names);
    catch err
        fc = err;
    end
    tb.no_overlap = true;
    tb.forecasts = fc;
    return
end
tb.accuracy = acc;
if nf > 1
    try
        tb.compare = fcompare(y, py, origin = origin, trunc = trunc, ...
            series = series, names = names);
    catch err
        tb.compare = err;
    end
end
end
