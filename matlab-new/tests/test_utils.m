function tests = test_utils
% Tests of the utilities (as tests/testthat/test-utils.R of the R package).
tests = functiontests(localfunctions);
end

function test_as_tsx_matrix_inputs(tc)
[y, nm] = as_tsx_matrix(1:10);
tc.verifyEqual(size(y), [10, 1]);
tc.verifyEqual(nm, "#1");
[~, nm] = as_tsx_matrix(table((1:3)', (4:6)', 'VariableNames', {'a', 'b'}));
tc.verifyEqual(nm, ["a", "b"]);
[~, nm] = as_tsx_matrix(reshape(1:6, 3, 2), names = "x y");
tc.verifyEqual(nm, ["x", "y"]);
[~, nm] = as_tsx_matrix(reshape(1:9, 3, 3), names = "x");
tc.verifyEqual(nm, ["x", "#2", "#3"]);
tc.verifyEqual(size(as_tsx_matrix(tsxt_data("airpas")), 1), 144);
% table with a date column and timetable
d = datetime(2024, 1, 1) + caldays(0:4)';
t = table(d, [3; 1; 4; 1; 5], 'VariableNames', {'date', 'x'});
[y, nm, dates] = as_tsx_matrix(t);
tc.verifyEqual(y, [3; 1; 4; 1; 5]);
tc.verifyEqual(nm, "x");
tc.verifyEqual(dates, d);
[y, ~, dates] = as_tsx_matrix(timetable(d, [3; 1; 4; 1; 5]));
tc.verifyEqual(size(y), [5, 1]);
tc.verifyEqual(dates, d);
end

function test_as_tsx_matrix_removes_missing_rows_at_the_ends(tc)
y = [NaN NaN; NaN 2; 1 1; NaN NaN; 3 3; NaN NaN];
[out, ~, ~, idx] = as_tsx_matrix(y);
tc.verifyEqual(size(out, 1), 4);
tc.verifyEqual(idx, (2:5)');
tc.verifyEqual(size(as_tsx_matrix(y, trim = false), 1), 6);
tc.verifyEqual(as_tsx_matrix([NaN 1 2]), [1; 2]);
end

function test_invalid_inputs(tc)
a = tsxt_data("airpas");
tc.verifyError(@() as_tsx_matrix("a"), 'tsexplorer:input');
tc.verifyError(@() as_tsx_matrix(table([1; 2], ["a"; "b"])), 'tsexplorer:input');
tc.verifyError(@() as_tsx_matrix([NaN NaN]), 'tsexplorer:input');
tc.verifyError(@() vident(a, series = 3), 'tsexplorer:series');
tc.verifyError(@() vident(a, series = "zz"), 'tsexplorer:series');
tc.verifyError(@() vident2(a), 'tsexplorer:vident2');
tc.verifyError(@() vgranger(a), 'tsexplorer:vgranger');
tc.verifyError(@() vident(a, ncoef = -1), 'tsexplorer:option');
end

function test_utilities_match_the_reference_values(tc)
u = tsxt_ref("utilities");
tsxt_expect_ref(tc, vdif(tsxt_data("la"), [1 1], [1 12]), u.vdif_la);
lp = tsxt_data("lp");
tsxt_expect_ref(tc, vdif([lp, lp], [1 0; 1 1], [1 12]), u.vdif_lp);
sv = tsxt_ref_input("sim_var3.csv");
tsxt_expect_ref(tc, tsexplorer.internal.tsx_delay(sv(1:10, :), [0 1 3]), u.delay);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_prctile(tsxt_data("scc"), [10 25 50 75 90]), u.prctile);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_standardize(sv(1:10, :)), u.transform);
sn = tsxt_ref_input("sim_na.csv");
tsxt_expect_ref(tc, tsexplorer.internal.tsx_nancov(sn(1:30, :)), u.nancov);
tsxt_expect_ref(tc, meda(tsxt_data("scc")), u.meda);
v = tsexplorer.internal.tsx_mvar(sv - mean(sv), 1:2, true);
tsxt_expect_ref(tc, v.p, u.mvar_p);
tsxt_expect_ref(tc, v.sigma, u.mvar_sigma);
tsxt_expect_ref(tc, [v.aic, v.sbc], [u.mvar_aic, u.mvar_sbc]);
dla = tsxt_data("dla");
a = tsexplorer.internal.tsx_auxvarsbc(dla - mean(dla), 3);
tsxt_expect_ref(tc, [a.fpe, a.aic, a.aicc, a.sbc, a.hqc, a.sigma], u.auxvarsbc);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_ksdensity(dla, u.ksdensity_x), u.ksdensity);
end

function test_nelder_mead_simplex_matches_the_reference_values(tc)
u = tsxt_ref("utilities");
a = tsxt_data("airpas");
g = tsexplorer.internal.tsx_fminsearch(@(l) tsexplorer.internal.tsx_guerrero(l, a, 12), 1);
tsxt_expect_ref(tc, g.par, u.fminsearch_guerrero);
r = tsexplorer.internal.tsx_fminsearch(@(x) 100 * (x(2) - x(1) ^ 2) ^ 2 + (1 - x(1)) ^ 2, [-1.2, 1]);
tsxt_expect_ref(tc, r.par, u.fminsearch_rosen);
% and fminsearch gives the same result
tsxt_expect_ref(tc, r.par, fminsearch(@(x) 100 * (x(2) - x(1) ^ 2) ^ 2 + (1 - x(1)) ^ 2, ...
    [-1.2, 1]), 1e-10);
end

function test_signed_rank_test_matches_the_reference_values(tc)
u = tsxt_ref("utilities");
sr = tsxt_ref_input("sim_signrank.csv");
% exact (n <= 15) and normal approximation with ties
tsxt_expect_ref(tc, fliplr(tsexplorer.internal.tsx_signrank(sr(1:10, 1), sr(1:10, 2))), u.signrank(1, :));
tsxt_expect_ref(tc, fliplr(tsexplorer.internal.tsx_signrank(sr(:, 1), sr(:, 2))), u.signrank(2, :));
% without ties: exact p-value of R's wilcox.test(x, y, paired = TRUE, exact = TRUE)
x = [1.83, 0.50, 1.62, 2.48, 1.68, 1.88, 1.55, 3.06, 1.30];
y = [0.878, 0.647, 0.598, 2.05, 1.06, 1.29, 1.06, 3.14, 1.29];
w = tsexplorer.internal.tsx_signrank(x, y);
tsxt_expect_ref(tc, w, [40, 0.0390625], 1e-12);
end

function test_adfcritical_interpolates_the_dickey_fuller_tables(tc)
% exact at the tabulated points
tsxt_expect_ref(tc, adfcritical(-2.89, 100, "t_const"), 0.05, 1e-12);
tsxt_expect_ref(tc, adfcritical(-3.45, 100, "t_trend"), 0.05, 1e-12);
tsxt_expect_ref(tc, adfcritical(4.71, 100, "f_const"), 0.05, 1e-12);
tc.verifyEqual(adfcritical([-10 10], 100, "t_none"), [0 1]);
tc.verifyEqual(adfcritical([0 50], 100, "f_trend"), [1 0]);
% linear interpolation on the stored triangulation
u = tsxt_ref("utilities");
tabs = ["t_none", "t_const", "t_trend", "f_const", "f_trend"];
for d = 1:5
    g = zeros(numel(u.adfcritical_t), numel(u.adfcritical_x));
    for k = 1:numel(u.adfcritical_t)
        g(k, :) = adfcritical(u.adfcritical_x', u.adfcritical_t(k), tabs(d));
    end
    tsxt_expect_ref(tc, g, squeeze(u.adfcritical(d, :, :)), 1e-10);
end
end

function test_distributions_without_toolboxes(tc)
% values of R: pchisq(3, 2, lower.tail = FALSE), pf(2, 3, 10, lower.tail =
% FALSE), pt(-2, 5), pgamma(2, 3, scale = 0.5, lower.tail = FALSE),
% qnorm(0.975), pnorm(-1.5)
tsxt_expect_ref(tc, tsexplorer.internal.tsx_pchisq(3, 2, false), 0.22313016014842982, 1e-12);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_pf(2, 3, 10, false), 0.178007407375175397, 1e-12);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_pt(-2, 5), 0.050969739414929105, 1e-12);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_pgamma(2, 3, 0.5, false), 0.23810330555354431, 1e-12);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_qnorm(0.975), 1.959963984540054, 1e-12);
tsxt_expect_ref(tc, tsexplorer.internal.tsx_pnorm(-1.5), 0.066807201268858057, 1e-12);
end

function test_functions_are_found_without_hiding_matlab_functions(tc)
% the tools are called by their names; plot, print and fplot, which exist
% in MATLAB, are only reachable as tsexplorer.<name>
here = fileparts(fileparts(mfilename('fullpath')));
for f = ["vident", "adftest", "adfcritical", "sumstats", "tooltest", "toolforecast"]
    tc.verifyEqual(string(which(f)), string(fullfile(here, f + ".m")));
end
for f = ["plot", "print", "fplot"]
    tc.verifyEqual(string(which("tsexplorer." + f)), string(fullfile(here, '+tsexplorer', f + ".m")));
    tc.verifyFalse(startsWith(string(which(f)), string(here)));
end
end

function test_tooltest_runs_adftest_of_the_package_when_another_comes_first(tc)
% another function adftest first on the path (as that of the Econometrics
% Toolbox): adftest(y) calls it, but tooltest runs tsexplorer.adftest
here = fileparts(mfilename('fullpath'));
shadow = fullfile(here, 'fixtures', 'shadow');
addpath(shadow);
tc.addTeardown(@() rmpath(shadow));
tc.verifyEqual(adftest(1:10), "other adftest");
y = tsxt_data("la");
opts = tooltest_defaults(y);
run = tsexplorer.internal.tsx_gui_run(y, "#1", "adftest", opts, [], struct());
tc.verifyEqual(run.result.class(1), "tsx_adftest");
tc.verifyEqual(run.result.trend, tsexplorer.adftest(y, lags = opts.adftest.lags).trend);
end
