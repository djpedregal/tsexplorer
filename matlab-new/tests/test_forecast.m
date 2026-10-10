function tests = test_forecast
% Tests of the forecast evaluation tools (as test-forecast.R and the
% forecast part of test-dates.R).
tests = functiontests(localfunctions);
end

function f = fc()
f = tsxt_ref_input("sim_fc.csv");
end

function test_faccuracy_matches_the_reference_values(tc)
fo = tsxt_ref("forecast");
r = faccuracy(tsxt_data("la"), fc());
tc.verifyEqual(r.call.origin, 132);
% columns N, ME (bias), MAE and MASE of the reference
tsxt_expect_ref(tc, [r.table.n, r.table.bias, r.table.mae, r.table.mase], fo.trunc1.accuracy(:, 1:4));
h = r.by_horizon(r.by_horizon.forecast == 1, :);
tsxt_expect_ref(tc, [h.bias, h.mae, h.mase], fo.trunc1.horizon1(:, 1:3));
end

function test_comparison_tests_match_the_reference_values(tc)
% the reference values are computed with percentage error losses
fo = tsxt_ref("forecast");
lav = tsxt_data("la");
act = lav(133:144);
pe = (fc() - act) ./ act;
for tr = 1:2
    tab = tsexplorer.internal.tsx_compare_losses(struct('mspe', pe .^ 2, 'mape', abs(pe)), tr, 12);
    x = fo.("trunc" + tr);
    ms = tab(tab.loss == "mspe", :);
    ma = tab(tab.loss == "mape", :);
    tsxt_expect_ref(tc, [ms.sign, ms.p_sign, ms.wilcoxon, ms.p_wilcoxon], x.mspe(:, 3:6));
    tsxt_expect_ref(tc, [ma.sign, ma.p_sign, ma.wilcoxon, ma.p_wilcoxon], x.mape(:, 3:6));
    % long run variance with the autocovariances of lags 1..trunc
    tsxt_expect_ref(tc, [ms.dm, ms.p_dm, ma.dm, ma.p_dm], x.dm_fixed);
end
end

function test_fcompare_uses_squared_and_absolute_errors(tc)
lav = tsxt_data("la");
act = lav(133:144);
f = fc();
e = f - act;
for tr = 1:2
    r = fcompare(lav, f, trunc = tr);
    tc.verifyEqual(unique(r.table.loss, 'stable'), ["mse"; "mae"]);
    tc.verifyEqual(r.table, ...
        tsexplorer.internal.tsx_compare_losses(struct('mse', e .^ 2, 'mae', abs(e)), tr, 12));
    % Diebold-Mariano computed directly
    d = e(:, 1) .^ 2 - e(:, 2) .^ 2;
    dc = d - mean(d);
    acs = 0;
    for k = 1:tr
        acs = acs + sum(dc((k + 1):end) .* dc(1:(12 - k)));
    end
    lrv = var(dc) + 2 * acs / 12;
    dm = mean(d) / sqrt(lrv / 12);
    row = r.table(r.table.f1 == 1 & r.table.f2 == 2 & r.table.loss == "mse", :);
    tsxt_expect_ref(tc, row.dm, dm, 1e-12);
    tsxt_expect_ref(tc, row.p_dm, erfc(abs(dm) / sqrt(2)), 1e-12);
end
% sign test computed directly
row = r.table(r.table.f1 == 1 & r.table.f2 == 3 & r.table.loss == "mae", :);
n1 = sum(abs(e(:, 1)) > abs(e(:, 3)));
tsxt_expect_ref(tc, row.sign, (n1 - 6) / (0.5 * sqrt(12)), 1e-12);
end

function test_bias_mae_rmse_and_interval_measures(tc)
lav = tsxt_data("la");
f = fc();
act = lav(133:144);
% standard deviations of the three forecasts (growing with the horizon)
st = sqrt((1:12)') * [0.025, 0.04, 0.015];
for lv = [0.95, 0.8]
    r = faccuracy(lav, f, stdpy = st, level = lv);
    al = 1 - lv;
    z = tsexplorer.internal.tsx_qnorm(1 - al / 2);
    for k = 1:3
        e = f(:, k) - act;
        lo = f(:, k) - z * st(:, k);
        up = f(:, k) + z * st(:, k);
        tab = r.table(k, :);
        tsxt_expect_ref(tc, tab.rmse, sqrt(mean(e .^ 2)), 1e-12);
        tsxt_expect_ref(tc, tab.bias_mae, abs(mean(e)) + mean(abs(e)), 1e-12);
        tsxt_expect_ref(tc, tab.coverage, mean(act >= lo & act <= up), 1e-12);
        tsxt_expect_ref(tc, tab.range, mean(up - lo), 1e-12);
        mis = mean((up - lo) + 2 / al * max(lo - act, 0) + 2 / al * max(act - up, 0));
        tsxt_expect_ref(tc, tab.mis, mis, 1e-12);
        pin = @(q, tau) mean((act >= q) .* tau .* (act - q) + (act < q) .* (1 - tau) .* (q - act));
        tsxt_expect_ref(tc, tab.pinball_lower, pin(lo, al / 2), 1e-12);
        tsxt_expect_ref(tc, tab.pinball_upper, pin(up, 1 - al / 2), 1e-12);
        h = r.by_horizon(r.by_horizon.forecast == k, :);
        tsxt_expect_ref(tc, h.rmse(12), tab.rmse, 1e-12);
        tsxt_expect_ref(tc, h.bias_mae(3), abs(mean(e(1:3))) + mean(abs(e(1:3))), 1e-12);
        tsxt_expect_ref(tc, h.coverage(3), mean(act(1:3) >= lo(1:3) & act(1:3) <= up(1:3)), 1e-12);
    end
end
% without intervals the interval measures are NaN
r = faccuracy(lav, f);
tc.verifyTrue(all(isnan(table2array(r.table(:, {'coverage', 'range', 'mis', ...
    'pinball_lower', 'pinball_upper'}))), 'all'));
tc.verifyEqual(string(r.table.Properties.VariableNames(2:5)), ["n", "bias", "mae", "bias_mae"]);
tc.verifyError(@() faccuracy(lav, f, stdpy = st, level = 95), 'tsexplorer:level');
% standard deviations of the first forecast only
r1 = faccuracy(lav, f, stdpy = st(:, 1));
tsxt_expect_ref(tc, r1.table.mis(1), faccuracy(lav, f, stdpy = st).table.mis(1), 1e-12);
tc.verifyTrue(all(isnan(r1.table.mis(2:3))));
tc.verifyError(@() faccuracy(lav, f, stdpy = [st, st]), 'tsexplorer:stdpy');
tc.verifyError(@() faccuracy(lav, f, stdpy = -st), 'tsexplorer:stdpy');
end

function test_bands_of_several_series_and_forecasts(tc)
% two series, two forecasts: columns (f1 s1, f1 s2, f2 s1, f2 s2)
y = [(1:20)', (21:40)'];
py = [(15:20)' + 0.5, (35:40)' - 0.5, (15:20)' - 1, (35:40)' + 1];
sd = repmat([0.1, 0.2, 0.3, 0.4], 6, 1);
z = tsexplorer.internal.tsx_qnorm(0.95);
p = tsexplorer.fplot(y, py, stdpy = sd, series = 2, forecast = "all", level = 0.9);
tc.verifyEqual(p.call.level, 0.9);
tsxt_expect_ref(tc, p.lower(15:20, :), py(:, [2 4]) - z * sd(:, [2 4]), 1e-12);
tsxt_expect_ref(tc, p.upper(15:20, :), py(:, [2 4]) + z * sd(:, [2 4]), 1e-12);
r = faccuracy(y, py, stdpy = sd, series = 1, level = 0.9);
tsxt_expect_ref(tc, r.table.range, 2 * z * [0.1; 0.3], 1e-12);
end

function test_alignment_of_actual_values_and_forecasts(tc)
lav = tsxt_data("la");
f = fc();
a = faccuracy(lav, f);
% actual data of the forecasting period only: origin 0, no MASE
b = faccuracy(lav(133:144), f);
tc.verifyEqual(b.call.origin, 0);
tc.verifyTrue(all(isnan(b.table.mase)));
tc.verifyEqual(a.table.mae, b.table.mae);
% full length forecasts with explicit origin
full = [nan(132, 3); f];
c1 = faccuracy(lav, full, origin = 132);
tc.verifyEqual(c1.table, a.table);
end

function test_forecasts_without_overlap(tc)
lav = tsxt_data("la");
full = [nan(144, 3); fc()];
for o = [0, 144]
    p = tsexplorer.fplot(lav, full, origin = o, forecast = "all");
    tc.verifyEqual(numel(p.actual), 156);
    tc.verifyError(@() faccuracy(lav, full, origin = o), 'tsexplorer:no_overlap');
    tc.verifyError(@() fcompare(lav, full, origin = o), 'tsexplorer:no_overlap');
end
% partial overlap still gives tables
part = [nan(138, 3); fc()];
tc.verifyEqual(faccuracy(lav, part, origin = 138).table.n, [6; 6; 6]);
end

function test_fplot_returns_the_plotted_data(tc)
lav = tsxt_data("la");
f = fc();
p = tsexplorer.fplot(lav, f(:, 1), stdpy = repmat(0.05, 12, 1));
tc.verifyEqual(p.origin, 132);
tc.verifyEqual(size(p.lower), [144, 1]);
tsxt_expect_ref(tc, p.upper(133:144, 1), f(:, 1) + tsexplorer.internal.tsx_qnorm(0.975) * 0.05, 1e-12);
tc.verifyEqual(p.errors(133:144, 1), f(:, 1) - lav(133:144));
p = tsexplorer.fplot(lav, f, forecast = "all", subsample = 12);
tc.verifyEqual(p.time, (133:144)');
tc.verifyEqual(size(p.forecasts, 2), 3);
tc.verifyError(@() tsexplorer.fplot(lav, f, forecast = 4), 'tsexplorer:forecast');
end

function test_dated_inputs_are_aligned_by_their_dates(tc)
lav = tsxt_data("la");
f = fc();
d = datetime(1949, 1, 1) + calmonths(0:143)';
dmid = datetime(1960, 7, 1) + calmonths(0:11)';
yt = timetable(d, lav);
% forecasts of 1960-07 to 1961-06: partial overlap of 6 periods
r = faccuracy(yt, timetable(dmid, f));
tc.verifyEqual(r.call.origin, 138);
tc.verifyEqual(r.table.n, [6; 6; 6]);
tsxt_expect_ref(tc, r.table.bias, mean(f(1:6, :) - lav(139:144))', 1e-12);
tc.verifyEqual(r.by_horizon.date(1), dmid(1));
% table with a date column, same result
ytab = table(d, lav, 'VariableNames', {'date', 'y'});
r2 = faccuracy(ytab, table(dmid, f, 'VariableNames', {'date', 'f'}));
tc.verifyEqual(r2.table, r.table);
% forecasts after the data: plot data with dates, no tables
dfut = datetime(1961, 1, 1) + calmonths(0:11)';
p = tsexplorer.fplot(yt, timetable(dfut, f), forecast = "all");
tc.verifyEqual(p.origin, 144);
tc.verifyEqual(p.dates, [d; dfut]);
tc.verifyError(@() faccuracy(yt, timetable(dfut, f)), 'tsexplorer:no_overlap');
% standard deviations: dated or with the rows of py
sd = 0.05 * sqrt((1:12)');
b1 = tsexplorer.fplot(yt, timetable(dmid, f(:, 1)), stdpy = sd);
b2 = tsexplorer.fplot(yt, timetable(dmid, f(:, 1)), stdpy = timetable(dmid, sd));
tc.verifyEqual(b1.lower, b2.lower);
% inputs of different types
tc.verifyError(@() faccuracy(yt, f), 'tsexplorer:type');
tc.verifyError(@() faccuracy(lav, timetable(dmid, f)), 'tsexplorer:type');
end

function test_forecast_functions_check_their_inputs(tc)
la = tsxt_data("la");
tc.verifyError(@() faccuracy(tsxt_data("scc"), la(1:12)), 'tsexplorer:py');
f = fc();
tc.verifyError(@() fcompare(la, f(:, 1)), 'tsexplorer:fcompare');
end
