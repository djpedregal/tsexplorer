function app = tooltest(y, varargin)
%TOOLTEST Interactive test tool.
%   Graphical interface with a menu with all the exploratory, descriptive
%   and diagnostic tools of the package, a selector of series, the options
%   of each tool and the graphical and text outputs. Every result shown can
%   be obtained without the interface by calling the corresponding function
%   (e.g. vident) and tsexplorer.print / tsexplorer.plot.
%
%   tooltest(Y)
%   tooltest(Y, "names", NAMES, TOOL1, OPTS1, ..., "visible", true)
%   APP = tooltest(...)
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     names    Optional names of the series.
%     TOOL, OPTS  Options per tool, e.g. "vident", struct('ncoef', 50,
%              's', 4, 'npar', 1) or "varspectrum", {16} (see
%              tooltest_defaults).
%     visible  false creates the windows without showing them (for tests).
%
%   Details:
%     The data may have no dates or have them (timetable, or table with a
%     datetime column; see as_tsx_matrix); with dates, the plots
%     with a time axis show them.
%
%     The interface is a window (uifigure) with the menus Tests (all the
%     tools, in groups), Series (selection of the series) and Options...
%     (options of the current tool), the navigation buttons <<< value >>>
%     (subsamples of plotband, highlighted group of the box plots) and the
%     text output, with the plots in a graphics window (figure) to its
%     right, without overlapping. Its text and graphics windows are
%     independent of those of toolforecast: a new call reuses
%     them and brings them to the front. Closing the text window closes
%     both.
%
%   Value:
%     APP      Struct with the windows (fig, and graphics(), a function
%              that returns the graphics figure), state(), a function that
%              returns the state of the interface (tool, s1, s2, all,
%              series, subsample, overlay, highlight, opts, error,
%              last_call and result, the object shown), widgets(), and
%              actions: functions that do what the widgets do (set_tool,
%              set_series, prev, nxt, set_nav, set_check, set_options,
%              options_dialog, close).
%
%   Examples:
%     y = load_data("airpas");
%     tooltest(y)
%     lp = load_data("lydia_pinkham");
%     tooltest(vdif(log(lp)), "vident", struct('ncoef', 12))
%     d = datetime(1949, 1:144, 1)';
%     tooltest(timetable(d, y, 'VariableNames', "passengers"))
%
%   See also tooltest_defaults, toolforecast,
%   tsexplorer.print, tsexplorer.plot.
names = [];
visible = true;
pairs = {};
k = 1;
while k <= numel(varargin)
    key = string(varargin{k});
    if k == numel(varargin)
        error('tsexplorer:tooltest', "Options must be given as pairs.");
    end
    switch key
        case "names"
            names = varargin{k + 1};
        case "visible"
            visible = logical(varargin{k + 1});
        otherwise
            pairs = [pairs, varargin(k:k + 1)]; %#ok<AGROW>
    end
    k = k + 2;
end
[y, names, dates] = as_tsx_matrix(y, names = names);
if ~isempty(dates)
    % the core functions get the dates through a timetable
    y = array2timetable(y, 'RowTimes', dates, 'VariableNames', cellstr(names));
end
[opts, links] = tooltest_defaults(y, pairs{:});
a = tsexplorer.internal.tsx_ui_tooltest(y, names, opts, links, visible);
if nargout > 0
    app = a;
end
end
