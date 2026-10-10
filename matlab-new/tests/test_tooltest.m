function tests = test_tooltest
% Tests of tooltest (as the tcltk tests of test-gui-tcltk.R): the
% interface is driven through its actions and by invoking its menus.
tests = functiontests(localfunctions);
end

function teardown(~)
% close the windows left by a test
app = tsexplorer.internal.tsx_ui_registry("get", "tooltest");
if ~isempty(app)
    app.actions.close();
end
end

function invoke(item)
% select a menu item as the user does
feval(item.MenuSelectedFcn, item, []);
end

function items = children(menu)
% menu items in their order on the screen
items = flipud(menu.Children);
end

function app = open_scc()
[scc, ns] = tsxt_data("scc");
app = tooltest(scc, "names", ns, "visible", false);
end

function test_menus_and_series_selection(tc)
app = open_scc();
w = app.widgets();
s = app.state();
tc.verifyEqual(s.tool, "plotband");
tc.verifyEqual(w.title.Text, 'Plot   [Series: y1]');
% Tests menu: one entry per tool, separators between groups
mt = findobj(app.fig, 'Type', 'uimenu', 'Text', 'Tests');
items = children(mt);
tools = tsexplorer.internal.tsx_tools();
tc.verifyEqual(string({items.Tag}), [tools.id]);
tc.verifyEqual(sum([items.Separator] == "on"), numel(unique([tools.group])) - 1);
invoke(items([tools.id] == "vident"));
tc.verifyEqual(app.state().tool, "vident");
tc.verifyEqual(app.state().result.class(1), "tsx_vident");
% the entries of the Series menu select their own series
sm = children(w.series_menu);
tc.verifyEqual(numel(sm), 3);
invoke(sm(2));
tc.verifyEqual(app.state().series, 2);
tc.verifyEqual(app.state().result.series, "y2");
invoke(sm(3));
tc.verifyEqual(app.state().series, 3);
% pairs (vident2): submenus of each series
app.actions.set_tool("vident2");
sm = children(w.series_menu);
sub = children(sm(1));
invoke(sub(2));
tc.verifyEqual(app.state().series, [1 2]);
invoke(sub(3));
tc.verifyEqual(app.state().series, [1 3]);
sub = children(sm(2));
invoke(sub(1));
tc.verifyEqual(app.state().series, 2);
ax = findobj(app.graphics(), 'Type', 'axes');
tc.verifyTrue(any(contains(string(arrayfun(@(h) string(h.Title.String), ax)), "Series y2")));
% "All" entries
app.actions.set_tool("varsbc");
sm = children(w.series_menu);
tc.verifyEqual(string(sm(end).Text), "All (VAR)");
invoke(sm(end));
tc.verifyEqual(app.state().series, "all");
tc.verifyEqual(app.state().result.series, ["y1", "y2", "y3"]);
% tables only: no series to select
app.actions.set_tool("adftest");
sm = children(w.series_menu);
tc.verifyEqual(sm(1).Enable, matlab.lang.OnOffSwitchState('off'));
tc.verifyTrue(any(contains(string(w.text.Value), "Augmented Dickey-Fuller")));
end

function test_navigation(tc)
app = open_scc();
w = app.widgets();
% subsamples of plotband
app.actions.nxt();
tc.verifyEqual(app.state().subsample, 1);
tc.verifyEqual(app.state().result.time(1), 1);
app.actions.set_nav("3");
tc.verifyEqual(app.state().subsample, 3);
tc.verifyEqual(w.entry.Value, '3');
% the core function clamps the value
app.actions.set_nav("100");
tc.verifyEqual(app.state().subsample, app.state().result.n_subsamples);
app.actions.prev();
tc.verifyEqual(app.state().subsample, app.state().result.n_subsamples - 1);
app.actions.set_check(true);
tc.verifyTrue(app.state().result.call.overlay);
% highlight of the boxplots
app.actions.set_tool("vboxplot");
tc.verifyEqual(w.nav_label.Text, 'Highlight:');
tc.verifyEqual(w.check.Enable, matlab.lang.OnOffSwitchState('off'));
app.actions.nxt();
tc.verifyEqual(app.state().highlight, 1);
tc.verifyEqual(numel(app.state().result.highlight), 6);
% no navigation
app.actions.set_tool("vident");
tc.verifyEqual(w.prev.Enable, matlab.lang.OnOffSwitchState('off'));
end

function test_options(tc)
app = open_scc();
app.actions.set_tool("vident");
app.actions.set_options(struct('ncoef', "12", 's', "4", 'npar', "1"));
s = app.state();
tc.verifyEqual(s.opts.vident.ncoef, 12);
tc.verifyEqual(height(s.result.table), 12);
tc.verifyEqual(s.last_call.args.npar, 1);
% linked options: the seasonal period and the lags of the correlograms
tc.verifyEqual(s.opts.plotband.s, 4);
tc.verifyEqual(s.opts.vboxcox.group, 4);
tc.verifyEqual(s.opts.vident2.ncoef, 12);
% invalid values give errors and do not change the options
tc.verifyError(@() app.actions.set_options(struct('ncoef', "2")), 'tsexplorer:option');
tc.verifyError(@() app.actions.set_options(struct('ncoef', "x")), 'tsexplorer:option');
tc.verifyEqual(app.state().opts.vident.ncoef, 12);
% vectors, matrices and selections
app.actions.set_tool("adftest");
app.actions.set_options(struct('lags', "1:3"));
tc.verifyEqual(app.state().result.call.lags, 1:3);
tc.verifyEqual(app.state().opts.johansentest.lags, 1:3);
app.actions.set_tool("testhet");
app.actions.set_options(struct('timecuts', "1 20; 30 62"));
tc.verifyEqual(app.state().result.samples, [1 20; 30 62]);
app.actions.set_tool("stdmean");
app.actions.set_options(struct('type', 1, 'numbers', false));
tc.verifyEqual(app.state().result.call.type, 1);
% options given when the tool is opened
[scc, ns] = tsxt_data("scc");
app = tooltest(scc, "names", ns, "visible", false, "vident", struct('ncoef', 8));
app.actions.set_tool("vident");
tc.verifyEqual(app.state().result.call.ncoef, 8);
end

function test_options_dialog(tc)
app = open_scc();
app.actions.set_tool("vspectrum");
d = app.actions.options_dialog();
tc.verifyClass(d, 'matlab.ui.Figure');
ok = findobj(d, 'Type', 'uibutton', 'Text', 'OK');
edit = findobj(d, 'Type', 'uieditfield');
edit.Value = '5';
feval(ok.ButtonPushedFcn, ok, []);
tc.verifyFalse(isvalid(d));
tc.verifyEqual(app.state().result.call.smooth, 5);
% tools without options: no dialog
app.actions.set_tool("vqqplot");
tc.verifyEmpty(app.actions.options_dialog());
end

function test_one_series_and_dates(tc)
[a, ~, d] = load_data("airpas");
app = tooltest(timetable(d, a), "names", "airpas", "visible", false);
mt = findobj(app.fig, 'Type', 'uimenu', 'Text', 'Tests');
tags = string({mt.Children.Tag});
% the tools for several series are not available
tc.verifyFalse(any(ismember(["vscatter", "vident2", "vgranger"], tags)));
tc.verifyEqual(app.state().result.dates(1), d(1));
app.actions.set_tool("vboxplot");
tc.verifyTrue(any(contains(string(app.widgets().text.Value), "1949-01")));
% errors of the core functions are shown, not raised
app.actions.set_tool("johansentest");
app.actions.set_options(struct('lags', "1"));
tc.verifyTrue(startsWith(string(app.widgets().text.Value{1}), "Error:"));
end

function test_windows_are_reused_and_closed(tc)
app = open_scc();
g = app.graphics();
fig = app.fig;
tc.verifyTrue(isvalid(g));
% a new call reuses the text and graphics windows
app2 = tooltest(tsxt_data("la"), "visible", false);
tc.verifyEqual(app2.fig, fig);
tc.verifyEqual(app2.graphics(), g);
tc.verifyEqual(app2.state().result.series, "#1");
% the previous state no longer owns the windows
app.actions.close();
tc.verifyTrue(isvalid(fig));
% the graphics window is opened again if the user closes it
delete(g);
app2.actions.set_tool("vident");
tc.verifyTrue(isvalid(app2.graphics()));
% closing the text window closes both
g = app2.graphics();
app2.actions.close();
tc.verifyFalse(isvalid(fig));
tc.verifyFalse(isvalid(g));
tc.verifyEmpty(tsexplorer.internal.tsx_ui_registry("get", "tooltest"));
end

function test_text_boxes_are_parsed_without_evaluating_code(tc)
p = @tsexplorer.internal.tsx_parse_numbers;
tc.verifyEqual(p("1:4"), 1:4);
tc.verifyEqual(p("1 2 12"), [1 2 12]);
tc.verifyEqual(p("[1, 3]"), [1 3]);
tc.verifyEqual(p("-1:0.5:1"), [-1 -0.5 0 0.5 1]);
tc.verifyEqual(p("1 30; 50 90", true), [1 30; 50 90]);
tc.verifyEmpty(p(""));
tc.verifyError(@() p("exit"), 'tsexplorer:option');
f = @tsexplorer.internal.tsx_format_numbers;
tc.verifyEqual(f(1:10), "1:10");
tc.verifyEqual(f(-1:0.1:1), "-1:0.1:1");
tc.verifyEqual(f([1 30; 50 90]), "1 30; 50 90");
end
