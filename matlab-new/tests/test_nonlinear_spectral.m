function tests = test_nonlinear_spectral
% Tests of the non-linearity and spectral tools (as
% test-nonlinear-spectral.R).
tests = functiontests(localfunctions);
end

function test_nltests_matches_the_reference_values(tc)
nl = tsxt_ref("nonlinear");
r = nltests(tsxt_data("dla"), ncoef = 12);
x = nl.nltests_dla;
t = r.table;
tsxt_expect_ref(tc, [t.acf, t.se_acf, t.q_mll, t.p_mll, t.pacf, t.q_mt, t.p_mt, t.d_pr, t.p_pr], ...
    [x.sacf, x.seacf, x.Q, x.PQ, x.spacf, x.Qmt, x.PQmt, x.Dm, x.pDm]);
end

function test_nltests_with_missing_values_uses_the_same_acf_as_vident(tc)
sn = tsxt_ref_input("sim_na.csv");
r = nltests(sn, ncoef = 10);
v = vident(sn .^ 2, ncoef = 10);
tc.verifyEqual(r.table.acf, v.table.acf);
end

function test_vtsay_is_the_f_test_of_the_cross_products_in_the_ar_regression(tc)
% Tsay (1986) with constant and F(k, n - p - k - 1); by the
% Frisch-Waugh-Lovell theorem it equals the F test of adding the cross
% products to the AR(p) regression with constant.
scc = tsxt_data("scc");
for y = {tsxt_data("dla"), scc(:, 3)}
    y = y{1}; %#ok<FXSET>
    p = 3;
    x = tsexplorer.internal.tsx_delay(y, 0:p);
    prods = zeros(size(x, 1), 0);
    for i = 1:p
        for j = i:p
            prods = [prods, x(:, i + 1) .* x(:, j + 1)]; %#ok<AGROW>
        end
    end
    n = size(x, 1);
    x0 = [ones(n, 1), x(:, 2:end)];
    x1 = [x0, prods];
    sse0 = sum((x(:, 1) - x0 * (x0 \ x(:, 1))) .^ 2);
    b1 = x1 \ x(:, 1);
    e1 = x(:, 1) - x1 * b1;
    sse1 = sum(e1 .^ 2);
    k = size(prods, 2);
    df2 = n - size(x1, 2);
    f = ((sse0 - sse1) / k) / (sse1 / df2);
    r = vtsay(y, lags = p);
    tsxt_expect_ref(tc, r.table.f, f, 1e-10);
    tc.verifyEqual(r.table.df2, df2);
    tsxt_expect_ref(tc, r.table.p_value, tsexplorer.internal.tsx_pf(f, k, df2, false), 1e-10);
    % coefficients of the auxiliary regression are those of the products
    s2 = sse1 / df2;
    se = sqrt(diag(s2 * inv(x1' * x1)));
    idx = (p + 2):size(x1, 2);
    tsxt_expect_ref(tc, r.regressions.beta, b1(idx), 1e-8);
    tsxt_expect_ref(tc, r.regressions.t, b1(idx) ./ se(idx), 1e-8);
end
end

function test_bds_statistic_matches_the_reference_values(tc)
nl = tsxt_ref("nonlinear");
dla = tsxt_data("dla");
b = tsexplorer.internal.tsx_bds(dla, 4, 1.5);
tsxt_expect_ref(tc, b.w, nl.bds_dla.w);
tsxt_expect_ref(tc, b.p_value, nl.bds_dla.sig);
tsxt_expect_ref(tc, [b.c1; b.k], [nl.bds_dla.c1; nl.bds_dla.k]);
b = tsexplorer.internal.tsx_bds(tsxt_ref_input("sim_ar1.csv"), 3, 1.2);
tsxt_expect_ref(tc, b.w, nl.bds_simar.w);
r = vbds(dla, maxdim = 4);
tsxt_expect_ref(tc, r.table.w, nl.bds_dla.w);
tc.verifyEqual(r.table.dim, (2:4)');
end

function test_varsbc2_detects_linearity(tc)
r = varsbc2(tsxt_ref_input("sim_ar1.csv") - 10, ncoef = 5);
tc.verifyEqual(height(r.table), 6);
tc.verifyClass(r.linear, 'logical');
end

function test_vcumperiod_matches_the_reference_values_on_demeaned_data(tc)
sp = tsxt_ref("spectral");
tsxt_expect_ref(tc, vcumperiod(tsxt_data("dla")).table.cum_periodogram, ...
    sp.cumper_dla.cumP_demeaned);
r = vcumperiod(tsxt_data("airpas"));
tsxt_expect_ref(tc, r.table.cum_periodogram, sp.cumper_a.cumP_demeaned);
tsxt_expect_ref(tc, [r.bands.p01; r.bands.p05], sp.cumper_a.conf);
end

function test_periodogram_and_cross_periodogram_match_the_reference_values(tc)
% frequencies are the Fourier frequencies 2 pi j / T
sp = tsxt_ref("spectral");
[ii, w] = tsexplorer.internal.tsx_mspectrum(vdif(tsxt_data("la")));
tsxt_expect_ref(tc, real(squeeze(ii(1, 1, :))), sp.mspectrum_dla.I);
tsxt_expect_ref(tc, w, 2 * pi * (0:floor(143 / 2))' / 143, 1e-14);
ii = tsexplorer.internal.tsx_mspectrum(tsxt_data("dlp"));
x = sp.mspectrum_dlp;
tsxt_expect_ref(tc, [real(squeeze(ii(1, 1, :))), real(squeeze(ii(2, 2, :))), ...
    real(squeeze(ii(1, 2, :))), imag(squeeze(ii(1, 2, :)))], [x.I11, x.I22, x.I12_re, x.I12_im]);
% with missing values the DFT skips them
tc.verifyFalse(any(isnan(vspectrum(tsxt_ref_input("sim_na.csv")).table.periodogram)));
end

function test_vspectrum_smoothing_and_coherence(tc)
dla1 = vdif(tsxt_data("la"));
r1 = vspectrum(dla1, smooth = 1);
tc.verifyEqual(r1.table.spectrum, r1.table.periodogram);
r5 = vspectrum(dla1, smooth = 4);
tc.verifyEqual(r5.call.smooth, 5);
b = [1 2 3 2 1]' / 9;
k = 10;
per = r1.table.periodogram;
tsxt_expect_ref(tc, r5.table.spectrum(k), sum(b .* per((k - 2):(k + 2))), 1e-12);
% symmetric extension at frequencies 0 and pi (T = 143, odd)
np = numel(per);
tsxt_expect_ref(tc, r5.table.spectrum(1), sum(b .* per([3 2 1 2 3])), 1e-12);
tsxt_expect_ref(tc, r5.table.spectrum(np), sum(b .* per([np - 2, np - 1, np, np, np - 1])), 1e-12);
% even T: the last frequency is pi
r1e = vspectrum(dla1(2:end), smooth = 1);
r5e = vspectrum(dla1(2:end), smooth = 5);
pe = r1e.table.periodogram;
ne = numel(pe);
tsxt_expect_ref(tc, r5e.table.spectrum(ne), sum(b .* pe([ne - 2, ne - 1, ne, ne - 1, ne - 2])), 1e-12);
r = vspectrum(tsxt_data("dlp"), smooth = 7, series = [1 2]);
tc.verifyTrue(all(r.table.coherence >= 0 & r.table.coherence <= 1 + 1e-12));
tsxt_expect_ref(tc, r.table.gain12 .* r.table.spectrum1, r.table.cross_amplitude, 1e-12);
end

function test_varspectrum_matches_the_reference_values(tc)
sp = tsxt_ref("spectral");
% spectrum sigma^2 / (2 pi) |1/phi|^2
dla1 = vdif(tsxt_data("la"));
r = varspectrum(dla1, order = 14, nfreq = 72);
k = r.sigma2 / (2 * pi ^ 2);
tsxt_expect_ref(tc, r.table.freq, sp.varspectrum_dla.freq);
tsxt_expect_ref(tc, r.table.spectrum, sp.varspectrum_dla.spectrum * k);
tsxt_expect_ref(tc, r.ar, sp.varspectrum_dla.ar);
r = varspectrum(dla1, order = 6, nfreq = 0);
x = sp.varspectrum_fourier;
tsxt_expect_ref(tc, [r.table.freq, r.table.spectrum], [x.freq, x.spectrum * r.sigma2 / (2 * pi ^ 2)]);
% AR(1): f(0) = sigma^2 / (2 pi) / (1 - phi)^2
w = tsxt_ref_input("sim_ar1.csv");
r = varspectrum(w(:, 1), order = 1);
tsxt_expect_ref(tc, r.table.spectrum(1), r.sigma2 / (2 * pi) / (1 - r.ar) ^ 2, 1e-12);
end
