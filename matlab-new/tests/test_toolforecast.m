function tests = test_toolforecast
% Tests of toolforecast (as the toolforecast tests of
% test-gui-tcltk.R and test-defaults-gui.R): the interface is driven through
% its actions and by invoking its menus.
tests = functiontests(localfunctions);
end

function teardown(~)
% close the windows left by a test
for kind = ["toolforecast", "tooltest"]
    app = tsexplorer.internal.tsx_ui_registry("get", kind);
    if ~isempty(app)
        app.actions.close();
    end
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

function f = fc()
f = tsxt_ref_input("sim_fc.csv");
end

function txt = text_of(app)
txt = string(app.widgets().text.Value);
end

function test_results_of_the_core_functions(tc)
y = tsxt_data("la");
f = fc();
app = toolforecast(y, f, "visible", false);
tc.verifyEqual(app.widgets().title.Text, 'Series: #1   Forecast: #1');
tc.verifyTrue(any(contains(text_of(app), "Forecast #1")));
tc.verifyTrue(any(contains(text_of(app), "Measures accumulated up to each period")));
app.actions.set_forecast("all");
app.actions.set_options(struct('s', "12", 'trunc', "2"));
s = app.state();
tc.verifyEqual(s.result.class(1), "tsx_fplot");
tc.verifyEqual(s.last_call.fun, "fplot");
tc.verifyEqual(s.last_call.args.forecast, "all");
tc.verifyEqual(s.tables.accuracy, faccuracy(y, f));
tc.verifyEqual(s.tables.compare, fcompare(y, f, trunc = 2));
tc.verifyTrue(any(contains(text_of(app), "Diebold")));
app.actions.set_forecast(2);
app.actions.set_nav("12");
tc.verifyEqual(app.state().result.time, (133:144)');
tc.verifyEqual(app.widgets().entry.Value, '12');
txt = tsexplorer.internal.tsx_fgui_text(app.state().tables, app.state().forecast);
tc.verifyTrue(any(contains(txt, "Forecast #2")));
% fplot clamps the subperiod
app.actions.set_nav("100");
tc.verifyEqual(app.state().subsample, 12);
app.actions.prev();
tc.verifyEqual(app.state().subsample, 11);
app.actions.nxt();
tc.verifyEqual(app.state().subsample, 12);
end

function test_intervals_and_level(tc)
y = tsxt_data("la");
f = fc();
st = repmat(0.03, 12, 1);
app = toolforecast(y, f, stdpy = st, level = 0.9, visible = false);
s = app.state();
tc.verifyEqual(s.tables.accuracy, faccuracy(y, f, stdpy = st, level = 0.9));
z = @(p) sqrt(2) * erfinv(2 * p - 1);
tsxt_expect_ref(tc, s.result.upper(133:144, 1), f(:, 1) + z(0.95) * 0.03, 1e-12);
app.actions.set_options(struct('level', "0.8"));
tc.verifyEqual(app.state().tables.accuracy.call.level, 0.8);
tc.verifyFalse(isnan(app.state().tables.accuracy.table.mis(1)));
% the plot uses the new level too
tsxt_expect_ref(tc, app.state().result.upper(133:144, 1), f(:, 1) + z(0.9) * 0.03, 1e-12);
% invalid values give errors and do not change the options
tc.verifyError(@() app.actions.set_options(struct('level', "95")), 'tsexplorer:option');
tc.verifyError(@() app.actions.set_options(struct('s', "2")), 'tsexplorer:option');
tc.verifyEqual(app.state().level, 0.8);
% the intervals of one forecast are shown in the plot
app.actions.set_forecast(1);
tc.verifyTrue(any(contains(text_of(app), "coverage")));
tc.verifyError(@() toolforecast(y, f, level = 95, visible = false), ...
    'tsexplorer:level');
end

function test_forecasts_without_overlap(tc)
y = tsxt_data("la");
full = [nan(144, 3); fc()];
app = toolforecast(y, full, origin = 144, visible = false);
for f = {1, 2, "all"}
    app.actions.set_forecast(f{1});
    s = app.state();
    tc.verifyEqual(s.result.class(1), "tsx_fplot");
    tc.verifyTrue(s.tables.no_overlap);
    tc.verifyTrue(any(contains(tsexplorer.internal.tsx_fgui_text(s.tables, s.forecast), ...
        "forecasts only")));
end
tc.verifyTrue(any(contains(text_of(app), "F#3")));
app.actions.set_nav("13");
tc.verifyEqual(app.state().result.time, (145:156)');
% with standard deviations: the bounds of the intervals of one forecast
app = toolforecast(y, full, stdpy = repmat(0.05, 156, 3), origin = 144, ...
    level = 0.9, visible = false);
txt = text_of(app);
tc.verifyTrue(any(contains(txt, "lower, upper: bounds of the 90% prediction intervals")));
tc.verifyTrue(any(contains(txt, "upper")));
end

function test_menus(tc)
[scc, ns] = tsxt_data("scc");
f = [scc(end - 11:end, :), scc(end - 11:end, :) + 1];
app = toolforecast(scc, f, "names", ns, "visible", false);
w = app.widgets();
% Series menu: one entry per series
sm = children(w.series_menu);
tc.verifyEqual(string({sm.Text}), string(ns));
invoke(sm(2));
tc.verifyEqual(app.state().series, 2);
tc.verifyEqual(app.state().result.series, string(ns(2)));
tc.verifyTrue(startsWith(string(w.title.Text), "Series: " + ns(2)));
% Forecasts menu: #1, #2 and All (after a separator)
fm = children(w.forecast_menu);
tc.verifyEqual(string({fm.Text}), ["#1", "#2", "All"]);
tc.verifyEqual(fm(3).Separator, matlab.lang.OnOffSwitchState('on'));
invoke(fm(3));
tc.verifyEqual(app.state().forecast, "all");
tc.verifyTrue(any(contains(text_of(app), "Diebold")));
invoke(fm(2));
tc.verifyEqual(app.state().forecast, 2);
% one series and one forecast: no Series menu, no All entry nor comparison
y = tsxt_data("la");
g = fc();
app = toolforecast(y, g(:, 1), "visible", false);
tc.verifyEmpty(app.widgets().series_menu);
tc.verifyEqual(numel(app.widgets().forecast_menu.Children), 1);
tc.verifyEmpty(app.state().tables.compare);
end

function test_options_dialog(tc)
app = toolforecast(tsxt_data("la"), fc(), "visible", false);
d = app.actions.options_dialog();
tc.verifyClass(d, 'matlab.ui.Figure');
edits = findobj(d, 'Type', 'uieditfield');
tc.verifyEqual(string({edits.Value}), ["12", "1", "0.95"]);
edits(2).Value = '3';
ok = findobj(d, 'Type', 'uibutton', 'Text', 'OK');
feval(ok.ButtonPushedFcn, ok, []);
tc.verifyFalse(isvalid(d));
tc.verifyEqual(app.state().trunc, 3);
app.actions.set_forecast("all");
tc.verifyEqual(app.state().tables.compare.call.trunc, 3);
end

function test_dates(tc)
[a, ~, d] = load_data("airpas");
y = log(a);
f = fc();
app = toolforecast(timetable(d, y), timetable(d(133:144), f), "visible", false);
txt = text_of(app);
tc.verifyTrue(any(contains(txt, "Forecasting period: 1960-01 to 1960-12")));
tc.verifyTrue(any(contains(txt, "1960-06")));
tc.verifyEqual(app.state().result.dates(1), d(1));
% actual values and forecasts of different types
tc.verifyError(@() toolforecast(timetable(d, y), f, "visible", false), ...
    'tsexplorer:type');
end

function test_windows_are_reused_and_independent(tc)
[scc, ns] = tsxt_data("scc");
t1 = tooltest(scc, "names", ns, "visible", false);
f1 = toolforecast(tsxt_data("la"), fc(), "visible", false);
fig = f1.fig;
g = f1.graphics();
% toolforecast has its own windows: it does not reuse those of tooltest
tc.verifyNotEqual(fig, t1.fig);
tc.verifyNotEqual(g, t1.graphics());
% a new call reuses its windows
f2 = toolforecast(tsxt_data("la"), fc(), "visible", false);
tc.verifyEqual(f2.fig, fig);
tc.verifyEqual(f2.graphics(), g);
tc.verifyTrue(any(contains(text_of(f2), "Forecast #1")));
% and tooltest reuses its own windows, not those of toolforecast
t2 = tooltest(scc, "names", ns, "visible", false);
tc.verifyEqual(t2.fig, t1.fig);
tc.verifyTrue(isvalid(fig));
% the previous state no longer owns the windows
f1.actions.close();
tc.verifyTrue(isvalid(fig));
% the graphics window is opened again if the user closes it
delete(g);
f2.actions.nxt();
tc.verifyTrue(isvalid(f2.graphics()));
% closing the text window closes both
g = f2.graphics();
f2.actions.close();
tc.verifyFalse(isvalid(fig));
tc.verifyFalse(isvalid(g));
tc.verifyEmpty(tsexplorer.internal.tsx_ui_registry("get", "toolforecast"));
tc.verifyNotEmpty(tsexplorer.internal.tsx_ui_registry("get", "tooltest"));
end
