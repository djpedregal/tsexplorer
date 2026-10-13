function file = package_toolbox(outdir)
%PACKAGE_TOOLBOX Package tsexplorer as a MATLAB toolbox (.mltbx).
%   file = package_toolbox(outdir) writes tsexplorer-<version>.mltbx in the
%   folder OUTDIR (by default, the current folder) and returns its path. The
%   version is read from Contents.m. The toolbox holds the functions, the
%   package +tsexplorer and the data; not the tests, this folder or the
%   images. Attach the file to the GitHub release with the same version
%   (File Exchange gives it as the download).
%
%   The identifier must not change between versions: it is how MATLAB knows
%   that a new .mltbx is an update of the installed toolbox.
%
%   Example (from the folder of the toolbox):
%       addpath packaging
%       package_toolbox('..')
arguments
    outdir (1, 1) string = pwd
end
root = fileparts(fileparts(mfilename('fullpath')));
id = "3ce686ce-b1c3-4edc-9f4d-492647397622";

% version: line "% Version x.y.z dd-mmm-yyyy" of Contents.m
v = regexp(fileread(fullfile(root, 'Contents.m')), '% Version (\S+)', 'tokens', 'once');
version = string(v{1});

opts = matlab.addons.toolbox.ToolboxOptions(root, id);
opts.ToolboxName = "tsexplorer";
opts.ToolboxVersion = version;
opts.AuthorName = "Diego J. Pedregal";
opts.AuthorEmail = "diego.pedregal@uclm.es";
opts.AuthorCompany = "Universidad de Castilla-La Mancha";
opts.Summary = "Exploratory and diagnostic tools for time series and forecasts";
opts.Description = "Exploratory, descriptive and diagnostic tools for univariate " + ...
    "and multivariate time series (summary statistics, gaussianity tests, " + ...
    "sample autocorrelation functions, information criteria, Granger causality, " + ...
    "unit root and cointegration tests, heteroskedasticity and non-linearity " + ...
    "tests, spectral analysis) and tools to evaluate and compare forecasts " + ...
    "(accuracy measures, Diebold-Mariano, sign and Wilcoxon tests), with the " + ...
    "graphical interfaces tooltest and toolforecast. No toolbox is needed. " + ...
    "Note: adftest has the same name as a function of the Econometrics " + ...
    "Toolbox; with tsexplorer first on the path, adftest is the one of " + ...
    "tsexplorer, and tooltest always uses its own (tsexplorer.adftest). " + ...
    "Also available for R and Python: https://github.com/djpedregal/tsexplorer";
opts.ToolboxImageFile = fullfile(root, "images", "logo.png");
opts.MinimumMatlabRelease = "R2021a";
opts.ToolboxMatlabPath = string(root);

% files: everything but the tests, the packaging and the images
files = opts.ToolboxFiles;
rel = erase(files, string(root) + filesep);
keep = ~startsWith(rel, ["tests", "packaging", "images", "."]) & rel ~= "run_tests.m";
opts.ToolboxFiles = files(keep);

file = fullfile(outdir, "tsexplorer-" + version + ".mltbx");
opts.OutputFile = file;
matlab.addons.toolbox.packageToolbox(opts);
fprintf('%s (%d files)\n', file, nnz(keep));
end
