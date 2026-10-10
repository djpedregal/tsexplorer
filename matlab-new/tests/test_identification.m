function tests = test_identification
% Tests of the identification tools (as test-identification.R).
tests = functiontests(localfunctions);
end

function check_vident(tc, r, x)
t = r.table;
tsxt_expect_ref(tc, [t.acf, t.se_acf, t.q_lb, t.p_lb, t.pacf, t.se_pacf, t.q_mt, t.p_mt], ...
    [x.sacf, x.seacf, x.Q, x.PQ, x.spacf, x.sepacf, x.Qmt, x.PQmt]);
end

function test_vident_matches_the_reference_values(tc)
v = tsxt_ref("vident");
dla = tsxt_data("dla");
check_vident(tc, vident(dla), v.dla);
check_vident(tc, vident(dla, ncoef = 24, npar = 2), v.dla_npar2);
check_vident(tc, vident(tsxt_ref_input("sim_na.csv"), ncoef = 20), v.sim_na);
[scc, nm] = tsxt_data("scc");
check_vident(tc, vident(scc, ncoef = 10, series = 2), v.scc_2);
check_vident(tc, vident(scc, ncoef = 10, series = "y2", names = nm), v.scc_2);
end

function test_vident_default_lags_and_degrees_of_freedom(tc)
r = vident(tsxt_data("dla"));
tc.verifyEqual(r.call.ncoef, min(38, ceil(131 / 4 * 2)));
r = vident(tsxt_data("dla"), ncoef = 12, npar = 2);
tc.verifyTrue(all(isnan(r.table.p_lb(1:2))));
end

function check_vident2(tc, r, x)
m = numel(r.series);
nc = r.call.ncoef;
blk = @(arr) reshape(permute(arr, [1 3 2]), m * (nc + 1), m);
d = x.data;
tsxt_expect_ref(tc, blk(r.acf), d(:, 1:m));
tsxt_expect_ref(tc, blk(r.pacf), d(:, (m + 1):(2 * m)));
tsxt_expect_ref(tc, [blk(r.se_acf), blk(r.se_pacf)], d(:, (2 * m + 1):(4 * m)));
% column 5 (p_q) is not compared
st = r.stats;
tsxt_expect_ref(tc, [st.aic, st.sbc, st.chi, st.p_chi, st.det_sigma], x.stats(:, [1:4, 6]));
% Hosking (1980) / Li-McLeod (1981) portmanteau computed directly
r0i = inv(r.acf(:, :, 1));
n = round(1 / r.se_acf(1, 1, 1) ^ 2);
cum = zeros(nc, 1);
for k = 1:nc
    rk = r.acf(:, :, k + 1);
    cum(k) = trace(rk' * r0i * rk * r0i);
end
cum = cumsum(cum);
k = (1:nc)';
q = n * cum + m ^ 2 * k .* (k + 1) / (2 * n);
df = m ^ 2 * (k - r.call.npar);
expected = nan(nc, 1);
expected(df > 0) = tsexplorer.internal.tsx_pchisq(q(df > 0), df(df > 0), false);
tsxt_expect_ref(tc, st.p_q, expected, 1e-12);
end

function test_vident2_matches_the_reference_values(tc)
v = tsxt_ref("vident2");
dlp = tsxt_data("dlp");
check_vident2(tc, vident2(dlp, ncoef = 8, type = 0), v.dlp_type0);
check_vident2(tc, vident2(dlp, ncoef = 8, type = 1), v.dlp_type1);
check_vident2(tc, vident2(tsxt_ref_input("sim_var3.csv"), ncoef = 6, npar = 1), ...
    v.simvar_type0);
end

function test_varsbc_and_varsbc2_match_the_reference_values(tc)
v = tsxt_ref("varsbc");
dla = tsxt_data("dla");
r = varsbc(dla, ncoef = 15);
tsxt_expect_ref(tc, table2array(r.table(:, 2:end)), v.dla.data);
r2 = varsbc(tsxt_data("scc"), ncoef = 5, series = "all");
tsxt_expect_ref(tc, table2array(r2.table(:, 2:end)), v.scc_all.data);
tsxt_expect_ref(tc, varsbc2(dla, ncoef = 12).table.sbc, v.varsbc2_dla.sbc);
[~, k] = min(v.dla.data(:, 2));
tc.verifyEqual(r.best.sbc, k - 1);
end

function test_varsbc_with_one_series_of_several_uses_the_dimension_of_the_model(tc)
v = tsxt_ref("varsbc");
scc = tsxt_data("scc");
r = varsbc(scc, ncoef = 5, series = 2);
tsxt_expect_ref(tc, [r.table.aicc, r.table.sbc, r.table.hqc], v.scc_2.data(:, 1:3));
tc.verifyEqual(r.table, varsbc(scc(:, 2), ncoef = 5).table);
end

function test_vgranger_matches_the_reference_values(tc)
% covariance of the coefficients: kron(inv(X'X), Sigma)
v = tsxt_ref("vgranger");
cols = {'constraints', 'f', 'p_f', 'chi2', 'p_chi2'};
r = vgranger(tsxt_data("dlp"), lags = 1:3);
tc.verifyEqual(r.table.test, string(v.dlp.tests));
tsxt_expect_ref(tc, table2array(r.table(:, cols)), v.dlp.table_fixed);
sv = tsxt_ref_input("sim_var3.csv");
tsxt_expect_ref(tc, table2array(vgranger(sv, lags = 1:2).table(:, cols)), ...
    v.simvar.table_fixed);
tsxt_expect_ref(tc, table2array(vgranger(sv, lags = [1 3], tests = "a-bc bc-a").table(:, cols)), ...
    v.simvar_block.table_fixed);
end

function test_vgranger_agrees_with_a_single_equation_wald_test(tc)
dlp = tsxt_data("dlp");
y = dlp - mean(dlp);
n = size(y, 1);
x = [y(2:(n - 1), :), y(1:(n - 2), :)];
yy = y(3:n, 1);
b = x \ yy;
e = yy - x * b;
sig = sum(e .^ 2) / n;
ixx = inv(x' * x);
v = ixx([2 4], [2 4]) * sig;
w = b([2 4])' * (v \ b([2 4]));
[~, nm] = load_data("lydia_pinkham");
r = vgranger(dlp, lags = 1:2, tests = "a-b", names = nm);
tsxt_expect_ref(tc, r.table.chi2, w, 1e-10);
tc.verifyTrue(contains(r.table.h0, "sales does not cause advertising"));
end
