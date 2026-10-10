function tests = test_defaults
% Tests of tooltest_defaults (as the core part of test-defaults-gui.R).
tests = functiontests(localfunctions);
end

function test_defaults_depend_on_the_data(tc)
a = tsxt_data("airpas");
d = tooltest_defaults(a);
tc.verifyEqual(d.vident.ncoef, min(38, ceil(144 / 4 * 2)));
tc.verifyEqual(d.adftest.lags, 1:12);
tc.verifyEqual(d.nltests.ncoef, 12);
tc.verifyEqual(d.varspectrum.nfreq, 72);
tc.verifyEmpty(d.vgranger.tests);
d3 = tooltest_defaults(tsxt_data("scc"));
tc.verifyEqual(d3.adftest.lags, 7);
tc.verifyEqual(numel(d3.vgranger.tests), 6);
end

function test_options_and_linked_options(tc)
a = tsxt_data("airpas");
d = tooltest_defaults(a, "vident", struct('ncoef', 50, 's', 4), "varspectrum", {16});
tc.verifyEqual(d.vident.ncoef, 50);
% linked: the seasonal period and the lags of the correlograms
tc.verifyEqual(d.plotband.s, 4);
tc.verifyEqual(d.vboxcox.group, 4);
tc.verifyEqual(d.vident2.ncoef, 50);
tc.verifyEqual(d.varsbc.ncoef, 50);
tc.verifyEqual(d.varspectrum.order, 16);
d = tooltest_defaults(a, "adftest", struct('lags', 1:4));
tc.verifyEqual(d.johansentest.lags, 1:4);
tc.verifyError(@() tooltest_defaults(a, "zz", struct()), 'tsexplorer:options');
tc.verifyError(@() tooltest_defaults(a, "vident", struct('zz', 1)), 'tsexplorer:options');
end
