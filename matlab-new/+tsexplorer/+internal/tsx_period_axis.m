function fx = tsx_period_axis(w, logx)
%TSX_PERIOD_AXIS Frequency axis labelled with periods (12, 6, 4, 3, 2.4, 2):
%   coordinates x, limits lim, label lab, tick positions ticks and labels
%   ticklabels. With LOGX the axis is log10(frequency) (frequency 0 is not
%   plotted).
periods = [12, 6, 4, 3, 2.4, 2];
if ~logx
    fx = struct('x', w, 'lim', [0, pi], 'lab', "Period", ...
        'ticks', [0, 2 * pi ./ periods], 'ticklabels', ["Inf", string(periods)]);
else
    lw = log10(w);
    lw(w == 0) = NaN;
    fx = struct('x', lw, 'lim', [min(lw, [], 'omitnan'), log10(pi)], 'lab', "Log10(Period)", ...
        'ticks', sort(log10(2 * pi ./ periods)), 'ticklabels', string(fliplr(periods)));
end
end
