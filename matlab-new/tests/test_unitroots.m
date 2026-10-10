function tests = test_unitroots
% Tests of the unit root and cointegration tests (as test-unitroots.R).
tests = functiontests(localfunctions);
end

function check_adf(tc, r, x)
tsxt_expect_ref(tc, [r.none.rho, r.none.t], [x.Rhont, x.tRhont]);
tsxt_expect_ref(tc, [r.const.rho, r.const.t, r.const.const, r.const.t_const], ...
    [x.Rho, x.tRho, x.Alfa, x.tAlfa]);
tsxt_expect_ref(tc, [r.trend.rho, r.trend.t, r.trend.const, r.trend.t_const, r.trend.trend, ...
    r.trend.t_trend], [x.Rhot, x.tRhot, x.Alfat, x.tAlfat, x.D, x.tD]);
% F statistics divided by the number of restrictions and Phi3 computed
% with the coefficient of the model with trend
tsxt_expect_ref(tc, r.const.f, x.F_fixed);
tsxt_expect_ref(tc, r.trend.f, x.Ft_fixed);
% p-values of the t statistics (stored triangulation)
tsxt_expect_ref(tc, [r.none.p_t, r.const.p_t, r.trend.p_t], [x.p_tRhont, x.p_tRho, x.p_tRhot]);
end

function test_adftest_matches_the_reference_values(tc)
ad = tsxt_ref("adftest");
check_adf(tc, adftest(tsxt_data("la"), lags = 1:4), ad.la);
check_adf(tc, adftest(tsxt_data("lp"), lags = 3), ad.lp);
check_adf(tc, adftest(tsxt_data("nile"), lags = 1:2), ad.nile);
end

function test_adftest_lags_and_structure(tc)
r = adftest(tsxt_data("la"));
tc.verifyEqual(r.call.lags, 1:12);
r = adftest(tsxt_data("lp"));
tc.verifyEqual(r.call.lags, 7);
tc.verifyEqual(height(r.const), 2);
tc.verifyEqual(tsexplorer.internal.tsx_unitroot_lags(100, 144, 1), 72);
tc.verifyError(@() adftest(tsxt_data("la"), lags = 100), 'tsexplorer:lags');
end

function test_vphillips_matches_the_reference_values(tc)
% the correction term is divided by the standard error of the regression
pp = tsxt_ref("vphillips");
for nm = ["la", "lp"]
    if nm == "la"
        r = vphillips(tsxt_data("la"), lags = 1:3, ncovs = 4);
    else
        r = vphillips(tsxt_data("lp"), lags = 3);
    end
    x = pp.(nm);
    tsxt_expect_ref(tc, [r.none.rho, r.const.rho, r.trend.rho], ...
        [x.rho_none, x.rho_const, x.rho_trend]);
    tsxt_expect_ref(tc, [r.none.z_t, r.const.z_t, r.trend.z_t], ...
        [x.z_none_fixed, x.z_const_fixed, x.z_trend_fixed]);
end
% each model uses its own statistic for the p-value
r = vphillips(tsxt_data("la"), lags = 1:3, ncovs = 4);
tc.verifyEqual(r.const.p_value, adfcritical(r.const.z_t, r.n, "t_const"));
tc.verifyEqual(r.trend.p_value, adfcritical(r.trend.z_t, r.n, "t_trend"));
end

function test_vphillips_without_lags_agrees_with_the_textbook_statistic(tc)
% Z(t) of Phillips and Perron (1988) with Bartlett weights, computed directly
z = tsxt_data("la");
n = numel(z);
r = vphillips(z, lags = 0, ncovs = 4);
y = z(2:n);
x = [z(1:(n - 1)), ones(n - 1, 1)];
b = x \ y;
e = y - x * b;
s2 = sum(e .^ 2) / (numel(e) - 2);
ixx = inv(x' * x);
se = sqrt(s2 * ixx(1, 1));
t0 = (b(1) - 1) / se;
g0 = sum(e .^ 2) / n;
lam = g0;
for k = 1:4
    lam = lam + 2 * (1 - k / 5) * sum(e((k + 1):end) .* e(1:(end - k))) / n;
end
zt = sqrt(g0 / lam) * t0 - 0.5 * (lam - g0) / sqrt(lam) * n * se / sqrt(s2);
tsxt_expect_ref(tc, r.const.z_t, zt, 1e-10);
end

function test_johansentest_matches_the_reference_values(tc)
jo = tsxt_ref("johansentest");
% p-values of the models with constant and trend are checked below
cols = {'stat_none', 'p_none', 'stat_const', 'stat_trend'};
ref_cols = [1, 2, 3, 5];
r = johansentest(tsxt_data("lp"), lags = 3);
tsxt_expect_ref(tc, table2array(r.table(:, cols)), jo.lp.table(:, ref_cols));
tsxt_expect_ref(tc, table2array(r.eigen(:, 2:end)), jo.lp.table2);
tc.verifyEqual(r.table.type, ["max"; "trace"; "max"]);
tsxt_expect_ref(tc, table2array(johansentest(tsxt_data("la"), lags = 2:4).table(:, cols)), ...
    jo.la.table(:, ref_cols));
sv = cumsum(tsxt_ref_input("sim_var3.csv"));
r = johansentest(sv, lags = 2);
tsxt_expect_ref(tc, table2array(r.table(:, cols)), jo.simvar.table(:, ref_cols));
tc.verifyTrue(all(isnan(r.table.p_trend)));
end

function test_johansentest_p_values_use_the_tables_of_each_model(tc)
% 5% critical values of Johansen-Juselius (1990), Table A1 (unrestricted
% constant) and Osterwald-Lenum (1992), Table 0 (no deterministic terms)
p = @tsexplorer.internal.tsx_johansen_p;
tsxt_expect_ref(tc, p([3.962, 14.036, 15.197, 29.509], [1, 2, 2, 3], ...
    ["max", "max", "trace", "trace"], 3), repmat(0.05, 4, 1), 1e-12);
tsxt_expect_ref(tc, p([11.44, 12.53], [2, 2], ["max", "trace"], 1), [0.05; 0.05], 1e-12);
r = johansentest(tsxt_data("lp"), lags = 3);
tc.verifyEqual(r.table.p_const, p(r.table.stat_const, 2 - r.table.h0, r.table.type, 3));
end
