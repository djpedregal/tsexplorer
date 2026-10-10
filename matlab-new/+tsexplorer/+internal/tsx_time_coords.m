function co = tsx_time_coords(dates, t)
%TSX_TIME_COORDS Horizontal axis of the time plots. DATES are the dates of
%   the plotted rows (or []) and T their row numbers. Returns the
%   coordinates x (the dates, or the row numbers), the limits xlim (one
%   period of margin) and the axis label.
t = t(:);
if isempty(dates)
    co = struct('x', t, 'xlim', [t(1) - 1, t(end) + 1], 'lab', "Samples");
    return
end
x = dates(:);
if numel(x) > 1
    dx = min(diff(x));
elseif isdatetime(x)
    dx = days(1);
else
    dx = 1;
end
co = struct('x', x, 'xlim', [x(1) - dx, x(end) + dx], 'lab', "Time");
end
