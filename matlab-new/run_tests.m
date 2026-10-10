function results = run_tests()
%RUN_TESTS Run the tests of the MATLAB version of tsexplorer.
%   From the folder matlab-new:  matlab -batch "run_tests"
%   The tests compare the results with the reference files of
%   r/inst/extdata/reference and with independent computations, as the
%   tests of the R package.
here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fullfile(here, 'tests', 'helpers'));
results = runtests(fullfile(here, 'tests'));
disp(table(results));
fprintf('\n%d passed, %d failed, %d incomplete\n', sum([results.Passed]), ...
    sum([results.Failed]), sum([results.Incomplete]));
if any([results.Failed])
    error('tsexplorer:tests', 'Some tests failed.');
end
end
