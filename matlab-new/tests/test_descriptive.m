function tests = test_descriptive
% Tests of the descriptive tools (as test-descriptive.R).
tests = functiontests(localfunctions);
end

function test_sumstats_matches_the_reference_values(tc)
s = tsxt_ref("sumstats");
for nm = ["airpas", "scc", "sim_na"]
    if nm == "sim_na"
        y = tsxt_ref_input("sim_na.csv");
    else
        y = tsxt_data(nm);
    end
    r = sumstats(y);
    v = s.(nm).value;
    vals = table2array(r.stats(:, 2:end))';
    vals(11, :) = [];  % the mode is not in the MATLAB output
    % rows 7 (P(mean = 0)) and 15 (range) are checked separately
    keep = setdiff(1:22, [7, 15]);
    tsxt_expect_ref(tc, vals(keep, :), v(keep, :));
    % two sided p-value (twice the one sided value)
    tsxt_expect_ref(tc, r.stats.p_mean_zero, 2 * v(7, :));
    % range is max - min
    tsxt_expect_ref(tc, r.stats.range, v(13, :) - v(3, :));
    if ~isempty(r.cor)
        tsxt_expect_ref(tc, r.cor, s.(nm).corr);
    end
end
end

function test_sumstats_structure_mode_and_bootstrap(tc)
a = tsxt_data("airpas");
r1 = sumstats(a);
tc.verifyEqual(r1.class, ["tsx_sumstats", "tsx_result"]);
tc.verifyEmpty(r1.cor);
tc.verifyEqual(height(r1.stats), 1);
r3 = sumstats(tsxt_data("scc"));
tc.verifyEqual(size(r3.cor), [3, 3]);
tc.verifyEqual(r1.stats.median, median(a));
% mode: most frequent value, the smallest one in case of ties (MATLAB mode)
tc.verifyEqual(sumstats([3 1 2 2 3 NaN]).stats.mode, 2);
tc.verifyEqual(sumstats([5 4 4 5 9]).stats.mode, 4);
tc.verifyEqual(sumstats([2.5 1.5 3]).stats.mode, 1.5);
tc.verifyEqual(r1.stats.mode, mode(a));
b1 = sumstats(a, gaussian = false, nsimul = 200, seed = 1);
b2 = sumstats(a, gaussian = false, nsimul = 200, seed = 1);
tc.verifyEqual(b1.stats.p_mean_zero, b2.stats.p_mean_zero);
tc.verifyTrue(b1.stats.p_mean_zero >= 0 && b1.stats.p_mean_zero <= 1);
end

function test_gausstest_matches_the_reference_values(tc)
g = tsxt_ref("gausstest");
for nm = ["dla", "scc", "nile"]
    r = gausstest(tsxt_data(nm));
    x = g.(nm);
    tsxt_expect_ref(tc, [r.table.skewness, r.table.kurtosis], [x.skew, x.kurto]);
    tsxt_expect_ref(tc, [r.table.bj, r.table.p_bj], [x.beraj, x.pvalue]);
    % Kolmogorov-Smirnov statistic max(D+, D-) (reference 'D_full')
    tsxt_expect_ref(tc, [r.table.ksl, r.table.p_ksl], [x.D_full, x.Dc_full]);
end
r = gausstest(tsxt_data("scc"));
tsxt_expect_ref(tc, [r.bj_multi, r.p_bj_multi], [g.scc.vBJ, g.scc.PvBJ]);
end

function test_gausstest_with_missing_values_uses_the_number_of_observations(tc)
g = tsxt_ref("gausstest");
sn = tsxt_ref_input("sim_na.csv");
r = gausstest(sn);
n = sum(~isnan(sn));
tc.verifyEqual(r.table.n, n);
tsxt_expect_ref(tc, r.table.bj, g.sim_na.beraj * n / g.sim_na.T);
end

function test_vhist_and_vqqplot_return_the_plotted_data(tc)
dla = tsxt_data("dla");
h = vhist(dla, bins = 10);
tc.verifyEqual(sum(h.hist.count), numel(dla));
tc.verifyEqual(height(h.density), 181);
q = vqqplot(dla);
gr = tsxt_ref("graphics");
tsxt_expect_ref(tc, [q.table.theoretical, q.table.empirical], ...
    [gr.vqqplot_dla.qtheo, gr.vqqplot_dla.zi]);
% reference line through the quartiles of the data
tsxt_expect_ref(tc, q.line.y, [gr.vqqplot_dla.yini_fixed, gr.vqqplot_dla.yend_fixed]);
% missing values are dropped before computing the plotting positions
sn = tsxt_ref_input("sim_na.csv");
tc.verifyEqual(height(vqqplot(sn).table), sum(~isnan(sn)));
end

function test_boxplots_stdmean_and_vcusum_match_the_reference_values(tc)
gr = tsxt_ref("graphics");
a = tsxt_data("airpas");
r = vboxplot(a);
tsxt_expect_ref(tc, table2array(r.stats(:, 2:end)), gr.boxplot_a.box);
r = vtboxplot(a);
tsxt_expect_ref(tc, table2array(r.stats(:, 2:end)), gr.boxplot_a.tbox);
tsxt_expect_ref(tc, r.data, gr.boxplot_a.tdata);
for k = 0:2
    r = stdmean(a, s = 12, type = k);
    x = gr.("stdmean_a" + k);
    tsxt_expect_ref(tc, [r.table.location, r.table.dispersion], x.data);
    tsxt_expect_ref(tc, [r.coef.intercept, r.coef.slope], x.beta);
end
r = vcusum(tsxt_data("dla"));
t = r.table;
x = gr.vcusum_dla;
tsxt_expect_ref(tc, [t.cusum, t.cusumsq, t.cusum_upper, t.cusumsq_lower, t.cusumsq_upper], ...
    [x.cusum, x.cusumsq, x.band, x.bandsq]);
end

function test_plotband_and_vscatter_return_the_plotted_data(tc)
a = tsxt_data("airpas");
[scc, nm] = tsxt_data("scc");
p = plotband(a, s = 12, subsample = 2);
tc.verifyEqual(p.time, (13:24)');
tc.verifyEqual(p.data, a(13:24));
tsxt_expect_ref(tc, p.mean, mean(a), 1e-12);
o = plotband(a, overlay = true);
tc.verifyEqual(size(o.data), [12, 12]);
al = plotband(scc, series = "all", standard = true);
tc.verifyEqual(size(al.data, 2), 3);
v = vscatter(scc, names = nm);
tc.verifyEqual(height(v.coef), 6);
b = v.coef(v.coef.x == "y1" & v.coef.y == "y2", :);
tsxt_expect_ref(tc, [b.intercept, b.slope], ([ones(size(scc, 1), 1), scc(:, 1)] \ scc(:, 2))', 1e-10);
end
