function fig = plot(r, opts)
%PLOT Plot of a result of the package.
%   Draws the plot of a result of the package in the current figure (a new
%   one if there is none), replacing its contents. It is the plot shown by
%   tooltest and toolforecast. Only base MATLAB
%   graphics are used.
%
%   tsexplorer.plot(R)
%   tsexplorer.plot(R, series=S, figure=F)
%   FIG = tsexplorer.plot(...)
%
%   Arguments:
%     R        A result of a function of the package with a plot.
%     series   Only for vident2: one series (index) to plot its ACF and
%              partial function, or two series ([i j]) to plot their cross
%              correlations. Default 1.
%     figure   Figure in which to draw (default: the current figure).
%
%   Value:
%     FIG      The figure.
%
%   Details:
%     Each class has its own method, tsexplorer.internal.tsx_plot_<class>.
%     The figure uses the light theme (white background).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(vident(log(y)))
%     lp = load_data("lydia_pinkham");
%     tsexplorer.plot(vident2(log(lp)), series=[1 2])
%
%   See also tsexplorer.print.
arguments
    r struct
    opts.series = 1
    opts.figure = []
end
name = extractAfter(r.class(1), "tsx_");
fun = "tsexplorer.internal.tsx_plot_" + name;
if isempty(which(fun))
    error('tsexplorer:plot', "No plot available for objects of class %s.", r.class(1));
end
if isempty(opts.figure)
    f = gcf;
else
    f = opts.figure;
end
clf(f);
% light theme (white background, as in R): the colours of the plots (black
% series, red bands) are not visible on the dark theme of recent versions
try
    theme(f, "light");
catch
end
if name == "vident2"
    feval(fun, r, f, opts.series);
else
    feval(fun, r, f);
end
if nargout > 0
    fig = f;
end
end
