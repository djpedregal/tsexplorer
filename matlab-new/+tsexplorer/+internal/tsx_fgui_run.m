function run = tsx_fgui_run(y, py, stdpy, origin, names, series, forecast, s, subsample, level)
%TSX_FGUI_RUN Plot object of toolforecast: returns the call made to
%   tsexplorer.fplot (struct with fields fun and args) and its result (or
%   the MException).
if nargin < 10
    level = 0.95;
end
args = struct('origin', origin, 'series', series, 'forecast', forecast, 's', s, ...
    'subsample', subsample, 'level', level, 'names', names);
try
    res = tsexplorer.fplot(y, py, stdpy = stdpy, origin = origin, series = series, ...
        forecast = forecast, s = s, subsample = subsample, level = level, names = names);
catch err
    res = err;
end
run = struct('call', struct('fun', "fplot", 'args', args), 'result', res);
end
