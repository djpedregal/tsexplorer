function app = tsx_ui_tooltest(y, names, opts, links, visible)
%TSX_UI_TOOLTEST Window of tooltest (tooltest_tk in R). The state
%   of the interface lives in the variables of this function, shared by its
%   nested functions; the widgets only call the actions (set_tool,
%   set_series, ...), which change the state and call refresh(). The
%   computations are done by the functions of the package through
%   tsx_gui_run, tsx_gui_text and tsx_gui_plot.
import tsexplorer.internal.*
if nargin < 5
    visible = true;
end
vis = matlab.lang.OnOffSwitchState(visible);
m = numel(names);
tools = tsx_tools_for(m);
% state
tool = "plotband";
s1 = 1;
s2 = 1;
all = false;
subsample = 0;
overlay = false;
highlight = 0;
err = [];
last_call = [];
result = [];
gfig = [];
own_gfig = true;
w = struct();

% windows: reuse those of a previous call while they are open
old = tsx_ui_registry("get", "tooltest");
[tpos, gpos] = tsx_ui_place(0);
if ~isempty(old)
    fig = old.fig;
    gfig = old.graphics();
    gpos = old.gpos;
    old.actions.detach();
    delete(fig.Children);
else
    fig = uifigure('Name', 'Test Tool', 'Position', tpos, 'Visible', vis);
end
fig.CloseRequestFcn = @(~, ~) close_app();
build();
actions = struct('set_tool', @set_tool, 'set_series', @set_series, 'prev', @prev, ...
    'nxt', @nxt, 'set_nav', @set_nav, 'set_check', @set_check, 'set_options', @set_options, ...
    'options_dialog', @options_dialog, 'close', @close_app, 'detach', @detach);
% nested functions (not anonymous ones, which would copy the current values)
app = struct('fig', fig, 'graphics', @get_graphics, 'gpos', gpos, 'state', @state, ...
    'actions', actions, 'widgets', @get_widgets);
tsx_ui_registry("set", "tooltest", app);
set_tool("plotband");
front();

    % ---------------------------------------------------------------- widgets
    function build()
        mfile = uimenu(fig, 'Text', 'File');
        uimenu(mfile, 'Text', 'Close', 'MenuSelectedFcn', @(~, ~) close_app());
        mtests = uimenu(fig, 'Text', 'Tests');
        last = "";
        for k = 1:numel(tools)
            t = tools(k);
            uimenu(mtests, 'Text', t.label, 'Separator', last ~= "" && t.group ~= last, ...
                'Tag', t.id, 'MenuSelectedFcn', @(~, ~) set_tool(t.id));
            last = t.group;
        end
        w.series_menu = uimenu(fig, 'Text', 'Series');
        uimenu(fig, 'Text', 'Options...', 'MenuSelectedFcn', @(~, ~) options_dialog());
        g = uigridlayout(fig, [3 1]);
        g.RowHeight = {22, 30, '1x'};
        w.title = uilabel(g, 'Text', '', 'FontWeight', 'bold');
        ng = uigridlayout(g, [1 5]);
        ng.ColumnWidth = {170, 50, 70, 50, '1x'};
        ng.Padding = [0 0 0 0];
        w.nav_label = uilabel(ng, 'Text', 'Subsample:');
        w.prev = uibutton(ng, 'Text', '<<<', 'ButtonPushedFcn', @(~, ~) prev());
        w.entry = uieditfield(ng, 'text', 'Value', '0', 'HorizontalAlignment', 'center', ...
            'ValueChangedFcn', @(src, ~) set_nav(src.Value));
        w.nxt = uibutton(ng, 'Text', '>>>', 'ButtonPushedFcn', @(~, ~) nxt());
        w.check = uicheckbox(ng, 'Text', 'All subsamples overlaid', ...
            'ValueChangedFcn', @(src, ~) set_check(src.Value));
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

    function menus()
        % Series menu and navigation controls for the current tool
        spec = tsx_tool_spec(tool);
        sm = w.series_menu;
        delete(sm.Children);
        switch spec.series
            case "none"
                uimenu(sm, 'Text', '(all the series are analysed)', 'Enable', 'off');
            case "single"
                for i = 1:m
                    add(sm, names(i), i, [], false);
                end
            case {"single_all", "var"}
                for i = 1:m
                    add(sm, names(i), i, [], false);
                end
                if spec.series == "var"
                    lab = "All (VAR)";
                else
                    lab = "All";
                end
                it = add(sm, lab, 1, [], true);
                it.Separator = 'on';
            case "pair"
                for i = 1:m
                    sub = uimenu(sm, 'Text', names(i));
                    for j = i:m
                        add(sub, names(i) + " - " + names(j), i, j, false);
                    end
                end
            case "pair_all"
                for i = 1:(m - 1)
                    sub = uimenu(sm, 'Text', names(i));
                    for j = (i + 1):m
                        add(sub, names(j), i, j, false);
                    end
                end
                it = add(sm, "All", 1, 2, true);
                it.Separator = 'on';
        end
        on = spec.nav ~= "";
        w.prev.Enable = on;
        w.entry.Enable = on;
        w.nxt.Enable = on;
        w.check.Enable = spec.nav == "subsample";
        if spec.nav == "highlight"
            w.nav_label.Text = 'Highlight:';
        else
            w.nav_label.Text = 'Subsample:';
        end
        w.check.Value = false;
    end

    function it = add(menu, label, i, j, a)
        % the indices are copied into the callback when it is created
        it = uimenu(menu, 'Text', label, 'MenuSelectedFcn', @(~, ~) set_series(i, j, a));
    end

    function update()
        % title, navigation value and text output after a refresh
        spec = tsx_tool_spec(tool);
        sel = selection();
        if isempty(sel)
            lab = "all series";
        elseif isstring(sel)
            lab = "All";
        else
            lab = strjoin(names(sel), " - ");
        end
        w.title.Text = spec.label + "   [Series: " + lab + "]";
        if spec.nav == "subsample"
            v = subsample;
        elseif spec.nav == "highlight"
            v = highlight;
        else
            v = 0;
        end
        w.entry.Value = string(v);
        w.text.Value = tsx_gui_text(result, err);
    end

    % ---------------------------------------------------------------- state
    function sel = selection()
        spec = tsx_tool_spec(tool);
        sel = tsx_gui_series(spec.series, s1, s2, all);
    end

    function refresh()
        spec = tsx_tool_spec(tool);
        nav = struct('subsample', subsample, 'overlay', overlay, 'highlight', highlight);
        run = tsx_gui_run(y, names, tool, opts, selection(), nav);
        last_call = run.call;
        result = run.result;
        % the core functions clamp the navigation values: show the effective one
        if ~isa(result, 'MException')
            if spec.nav == "subsample"
                subsample = result.call.subsample;
            elseif spec.nav == "highlight"
                highlight = result.call.highlight;
            end
        end
        if spec.plot
            graphics();
            tsx_gui_plot(result, tool, selection(), gfig);
        end
        update();
    end

    function graphics()
        % the graphics window: reuse it while it is open
        if isempty(gfig) || ~isvalid(gfig)
            gfig = figure('Name', 'Test Tool: plots', 'NumberTitle', 'off', 'Position', gpos, ...
                'Visible', vis);
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

    function s = state()
        s = struct('tool', tool, 's1', s1, 's2', s2, 'all', all, 'series', selection(), ...
            'subsample', subsample, 'overlay', overlay, 'highlight', highlight, 'opts', opts, ...
            'error', err, 'last_call', last_call, 'result', result);
    end

    % ---------------------------------------------------------------- actions
    function set_tool(id)
        id = string(id);
        if ~ismember(id, [tools.id])
            error('tsexplorer:tool', "Unknown tool: %s", id);
        end
        tool = id;
        spec = tsx_tool_spec(tool);
        s1 = 1;
        if spec.series == "pair_all"
            s2 = 2;
        else
            s2 = 1;
        end
        all = false;
        subsample = 0;
        overlay = false;
        highlight = 0;
        err = [];
        menus();
        refresh();
    end

    function set_series(i, j, a)
        if nargin < 2, j = []; end
        if nargin < 3, a = false; end
        s1 = i;
        if ~isempty(j)
            s2 = j;
        end
        all = a;
        refresh();
    end

    function prev()
        spec = tsx_tool_spec(tool);
        if spec.nav == "subsample", subsample = max(0, subsample - 1); end
        if spec.nav == "highlight", highlight = max(0, highlight - 1); end
        refresh();
    end

    function nxt()
        spec = tsx_tool_spec(tool);
        if spec.nav == "subsample", subsample = subsample + 1; end
        if spec.nav == "highlight", highlight = highlight + 1; end
        refresh();
    end

    function set_nav(value)
        v = str2double(string(value));
        if isnan(v), v = 0; end
        spec = tsx_tool_spec(tool);
        if spec.nav == "subsample", subsample = max(0, round(v)); end
        if spec.nav == "highlight", highlight = max(0, round(v)); end
        refresh();
    end

    function set_check(on)
        overlay = logical(on);
        refresh();
    end

    function set_options(values)
        % VALUES: struct with the values typed or selected for the options
        spec = tsx_tool_spec(tool);
        new = opts;
        for op = spec.options
            if isfield(values, op.name)
                new = tsx_gui_set_option(new, links, tool, op.name, ...
                    tsx_gui_parse_option(op, values.(op.name)));
            end
        end
        opts = new;
        refresh();
    end

    function d = options_dialog()
        spec = tsx_tool_spec(tool);
        d = tsx_ui_options_dialog(fig, "Options: " + spec.label, spec.options, opts.(tool), ...
            @set_options, visible);
    end

    function close_app()
        if ~isempty(gfig) && isvalid(gfig) && own_gfig
            delete(gfig);
        end
        if ~isempty(fig) && isvalid(fig)
            tsx_ui_registry("remove", "tooltest", fig);
            delete(fig);
        end
    end

    function detach()
        % a new call of tooltest takes over the windows
        fig = [];
        gfig = [];
    end
end
