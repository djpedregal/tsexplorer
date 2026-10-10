function app = tsx_ui_toolforecast(y, py, stdpy, origin, names, a, level, visible)
%TSX_UI_TOOLFORECAST Window of toolforecast (toolforecast_tk in
%   R). The state of the interface lives in the variables of this function,
%   shared by its nested functions; the widgets only call the actions
%   (set_series, set_forecast, ...), which change the state and call
%   refresh(). The computations are done by the functions of the package
%   through tsx_fgui_run, tsx_fgui_tables and tsx_fgui_text. A is the output
%   of tsx_forecast_align (names of the series and number of forecasts).
import tsexplorer.internal.*
if nargin < 7
    level = 0.95;
end
if nargin < 8
    visible = true;
end
vis = matlab.lang.OnOffSwitchState(visible);
series_names = a.names;
% state
s1 = 1;
forecast = 1;
s = 12;
subsample = 0;
trunc = 1;
last_call = [];
result = [];
tables = [];
gfig = [];
own_gfig = true;
w = struct();
options = [option("s", "Length of horizontal axis for plots [4, Inf)", "int", 4, []), ...
           option("trunc", "Truncation lag for Diebold-Mariano test [0, Inf)", "int", 0, []), ...
           option("level", "Confidence level of the intervals (0, 1)", "num", 0.001, 0.999)];

% windows: reuse those of a previous call while they are open
old = tsx_ui_registry("get", "toolforecast");
[tpos, gpos] = tsx_ui_place(40);
if ~isempty(old)
    fig = old.fig;
    gfig = old.graphics();
    gpos = old.gpos;
    old.actions.detach();
    delete(fig.Children);
else
    fig = uifigure('Name', 'Forecasting Tool', 'Position', tpos, 'Visible', vis);
end
fig.CloseRequestFcn = @(~, ~) close_app();
build();
actions = struct('set_series', @set_series, 'set_forecast', @set_forecast, 'prev', @prev, ...
    'nxt', @nxt, 'set_nav', @set_nav, 'set_options', @set_options, ...
    'options_dialog', @options_dialog, 'close', @close_app, 'detach', @detach);
% nested functions (not anonymous ones, which would copy the current values)
app = struct('fig', fig, 'graphics', @get_graphics, 'gpos', gpos, 'state', @state, ...
    'actions', actions, 'widgets', @get_widgets);
tsx_ui_registry("set", "toolforecast", app);
refresh();
front();

    % ---------------------------------------------------------------- widgets
    function build()
        mfile = uimenu(fig, 'Text', 'File');
        uimenu(mfile, 'Text', 'Close', 'MenuSelectedFcn', @(~, ~) close_app());
        w.series_menu = [];
        if numel(series_names) > 1
            w.series_menu = uimenu(fig, 'Text', 'Series');
            for i = 1:numel(series_names)
                add_series(i);
            end
        end
        w.forecast_menu = uimenu(fig, 'Text', 'Forecasts');
        for f = 1:a.nf
            add_forecast("#" + f, f, false);
        end
        if a.nf > 1
            add_forecast("All", "all", true);
        end
        uimenu(fig, 'Text', 'Options...', 'MenuSelectedFcn', @(~, ~) options_dialog());
        g = uigridlayout(fig, [3 1]);
        g.RowHeight = {22, 30, '1x'};
        w.title = uilabel(g, 'Text', '', 'FontWeight', 'bold');
        ng = uigridlayout(g, [1 5]);
        ng.ColumnWidth = {170, 50, 70, 50, '1x'};
        ng.Padding = [0 0 0 0];
        w.nav_label = uilabel(ng, 'Text', 'Subperiod (0 = full sample):');
        w.prev = uibutton(ng, 'Text', '<<<', 'ButtonPushedFcn', @(~, ~) prev());
        w.entry = uieditfield(ng, 'text', 'Value', '0', 'HorizontalAlignment', 'center', ...
            'ValueChangedFcn', @(src, ~) set_nav(src.Value));
        w.nxt = uibutton(ng, 'Text', '>>>', 'ButtonPushedFcn', @(~, ~) nxt());
        if ispc
            mono = 'Consolas';
        else
            mono = 'Courier New';
        end
        w.text = uitextarea(g, 'Editable', 'off', 'FontName', mono, 'FontSize', 11);
        try
            w.text.WordWrap = 'off';
        catch
        end
    end

    function add_series(i)
        % the index is copied into the callback when it is created
        uimenu(w.series_menu, 'Text', series_names(i), ...
            'MenuSelectedFcn', @(~, ~) set_series(i));
    end

    function add_forecast(label, f, sep)
        uimenu(w.forecast_menu, 'Text', label, 'Separator', sep, ...
            'MenuSelectedFcn', @(~, ~) set_forecast(f));
    end

    function update()
        % title, navigation value and text output after a refresh
        if isstring(forecast)
            fl = "All";
        else
            fl = "#" + forecast;
        end
        w.title.Text = "Series: " + series_names(s1) + "   Forecast: " + fl;
        w.entry.Value = string(subsample);
        w.text.Value = tsx_fgui_text(tables, forecast);
    end

    % ---------------------------------------------------------------- state
    function refresh()
        run = tsx_fgui_run(y, py, stdpy, origin, names, s1, forecast, s, subsample, level);
        last_call = run.call;
        result = run.result;
        % fplot clamps the subperiod: show the effective one
        if ~isa(result, 'MException')
            subsample = result.call.subsample;
        end
        graphics();
        tsx_fgui_plot(result, gfig);
        tables = tsx_fgui_tables(y, py, stdpy, origin, s1, trunc, level, names, a.nf);
        update();
    end

    function graphics()
        % the graphics window: reuse it while it is open
        if isempty(gfig) || ~isvalid(gfig)
            gfig = figure('Name', 'Forecasting Tool: plots', 'NumberTitle', 'off', ...
                'Position', gpos, 'Visible', vis);
            own_gfig = true;
        end
    end

    function front()
        % bring the windows to the front
        if ~visible
            return
        end
        if ~isempty(gfig) && isvalid(gfig)
            figure(gfig);
        end
        figure(fig);
    end

    function g = get_graphics()
        g = gfig;
    end

    function ww = get_widgets()
        ww = w;
    end

    function st = state()
        st = struct('series', s1, 'forecast', forecast, 's', s, 'subsample', subsample, ...
            'trunc', trunc, 'level', level, 'last_call', last_call, 'result', result, ...
            'tables', tables);
    end

    % ---------------------------------------------------------------- actions
    function set_series(i)
        s1 = i;
        refresh();
    end

    function set_forecast(f)
        if (isstring(f) || ischar(f)) && string(f) == "all"
            forecast = "all";
        else
            forecast = round(double(f));
        end
        refresh();
    end

    function prev()
        subsample = max(0, subsample - 1);
        refresh();
    end

    function nxt()
        subsample = subsample + 1;
        refresh();
    end

    function set_nav(value)
        v = str2double(string(value));
        if isnan(v)
            subsample = 0;
        else
            subsample = max(0, round(v));
        end
        refresh();
    end

    function set_options(values)
        % VALUES: struct with the values typed for the options (s, trunc,
        % level); all of them are parsed before any is changed
        new = struct('s', s, 'trunc', trunc, 'level', level);
        for op = options
            if isfield(values, op.name)
                new.(op.name) = tsx_gui_parse_option(op, values.(op.name));
            end
        end
        s = new.s;
        trunc = new.trunc;
        level = new.level;
        refresh();
    end

    function d = options_dialog()
        d = tsx_ui_options_dialog(fig, "Options", options, ...
            struct('s', s, 'trunc', trunc, 'level', level), @set_options, visible);
    end

    function close_app()
        if ~isempty(gfig) && isvalid(gfig) && own_gfig
            delete(gfig);
        end
        if ~isempty(fig) && isvalid(fig)
            tsx_ui_registry("remove", "toolforecast", fig);
            delete(fig);
        end
    end

    function detach()
        % a new call of toolforecast takes over the windows
        fig = [];
        gfig = [];
    end
end

function op = option(name, label, type, lo, hi)
% option of the Options dialog (fields as in tsx_tools)
op = struct('name', string(name), 'label', string(label), 'type', string(type), ...
    'min', lo, 'max', hi, 'choice_labels', strings(0), 'choice_values', []);
end
