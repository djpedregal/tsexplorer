function tests = test_heteroskedasticity
% Tests of the heteroskedasticity tools (as test-heteroskedasticity.R).
tests = functiontests(localfunctions);
end

function test_testhet_matches_the_reference_values(tc)
th = tsxt_ref("testhet");
a = tsxt_data("airpas");
cases = struct('airpas', testhet(a), ...
    'airpas_cuts', testhet(a, timecuts = [48 96]), ...
    'airpas_matrix', testhet(a, timecuts = [1 30; 50 90; 100 144]), ...
    'scc', testhet(tsxt_data("scc")));
for nm = string(fieldnames(cases))'
    r = cases.(nm);
    tsxt_expect_ref(tc, r.samples, th.(nm).timecuts);
    % degrees of freedom n - 1 (column 6 of the reference)
    tsxt_expect_ref(tc, [r.table.f, r.table.p_value], th.(nm).table(:, [4 6]));
end
end

function test_testhet_time_cuts(tc)
a = tsxt_data("airpas");
r = testhet(a, timecuts = [48 96]);
tc.verifyEqual(r.samples, [1 48; 49 96; 97 144]);
% invalid cuts fall back to the default three subsamples
tc.verifyEqual(size(testhet(a, timecuts = 2).samples, 1), 3);
% rows of a matrix starting before observation 5 are removed (only after
% the first one)
r = testhet(a, timecuts = [1 40; 3 60; 70 144]);
tc.verifyEqual(r.samples, [1 40; 70 144]);
end

function test_vboxcox_matches_the_reference_values(tc)
% Guerrero method and the Nelder-Mead simplex
bc = tsxt_ref("vboxcox");
r = vboxcox(tsxt_data("airpas"), group = 12);
tsxt_expect_ref(tc, r.lambdas, bc.airpas.lambdas);
tsxt_expect_ref(tc, table2array(r.grid(:, 2:7)), [bc.airpas.grid, bc.airpas.grid_std]);
r = vboxcox(tsxt_data("lydia_pinkham"), group = 6, ...
    axislambdas = tsexplorer.internal.tsx_seq_by(-1, 1, 0.25), series = 2);
tsxt_expect_ref(tc, r.lambdas, bc.lydia.lambdas);
tsxt_expect_ref(tc, table2array(r.grid(:, 2:7)), [bc.lydia.grid, bc.lydia.grid_std]);
end

function test_vboxcox_transforms_with_given_lambdas(tc)
a = tsxt_data("airpas");
r = vboxcox(a, lambdas = 0);
tc.verifyFalse(r.estimated);
tc.verifyEqual(r.transformed, log(a));
r = vboxcox(tsxt_data("scc"), lambdas = [1 0.5]);
tc.verifyEqual(r.lambdas, [1 0.5 0.5]);
end
