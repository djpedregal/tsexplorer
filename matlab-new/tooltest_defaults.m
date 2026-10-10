function [def, links] = tooltest_defaults(y, varargin)
%TOOLTEST_DEFAULTS Default options of the tools of tooltest.
%   Single source of the default options of every tool (they depend on the
%   sample size T and the number of series m). It is used by the
%   tooltest application; the functions of the package resolve
%   the same defaults when their arguments are [].
%
%   [DEF, LINKS] = tooltest_defaults(Y)
%   [DEF, LINKS] = tooltest_defaults(Y, TOOL1, OPTS1, TOOL2, OPTS2, ...)
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     TOOL, OPTS  Options to override, given per tool: OPTS is a struct
%              with option names, e.g. "vident", struct('ncoef', 50, 's', 4,
%              'npar', 1), or a cell array with the values in the order of
%              the options of the tool, e.g. "varspectrum", {16}. When a
%              linked option is changed in one tool, it is propagated to
%              the other tools of its group (the last changed member of
%              each group wins, in a fixed order).
%
%   Details:
%     Some options are linked across tools: the seasonal period s
%     (plotband, vboxplot, vtboxplot, vident, vident2, stdmean and the
%     group of vboxcox), the number of lags of the correlograms (vident,
%     vident2, varsbc), the lags of the unit root tests (adftest,
%     vphillips, johansentest) and the number of lags of the non-linearity
%     tests (nltests, varsbc2). The groups are returned in LINKS.
%
%   Value:
%     DEF      Struct with one field per tool (plotband, vboxplot, ...,
%              varspectrum), each a struct of options.
%     LINKS    Struct with one field per group of linked options, each a
%              cell array of ["tool" "option"] pairs.
%
%   Examples:
%     y = load_data("airpas");
%     def = tooltest_defaults(y);
%     def.vident
%     def = tooltest_defaults(y, "vboxplot", struct('s', 4));
%     def.plotband.s
%
%   See also tooltest.
import tsexplorer.internal.*
y = as_tsx_matrix(y);
n = size(y, 1);
m = size(y, 2);
lmax = min(floor(sqrt(n)), 20);
if m == 1
    ur_lags = 1:lmax;
    gtests = [];
else
    ur_lags = lmax;
    gtests = tsx_granger_tests([], m);
end
nc_acf = min(38, ceil(n / 4 / m * 2));
nc_nl = min(38, ceil(sqrt(n)));
def = struct();
def.plotband = struct('s', 12, 'standard', false, 'fixed', true);
def.vboxplot = struct('s', 12);
def.vtboxplot = struct('s', 12);
def.vscatter = struct('bins', ceil(sqrt(n)));
def.sumstats = struct('digits', 4, 'gaussian', true, 'nsimul', 3000);
def.vhist = struct('bins', ceil(sqrt(n)));
def.vqqplot = struct();
def.gausstest = struct('digits', 4);
def.vident = struct('ncoef', nc_acf, 's', 12, 'npar', 0);
def.vident2 = struct('ncoef', nc_acf, 's', 12, 'npar', 0, 'type', 0);
def.varsbc = struct('ncoef', nc_acf);
def.vgranger = struct('lags', 1:lmax, 'tests', gtests);
def.vcusum = struct();
def.stdmean = struct('s', 12, 'type', 0, 'numbers', true);
def.testhet = struct('timecuts', [floor(n / 3), floor(2 * n / 3) + 2]);
def.vboxcox = struct('group', 12, 'axislambdas', tsx_seq_by(-1, 1, 0.1));
def.adftest = struct('lags', ur_lags);
def.vphillips = struct('lags', ur_lags, 'ncovs', floor(4 * (n / 100) ^ 0.25));
def.johansentest = struct('lags', ur_lags);
def.nltests = struct('ncoef', nc_nl);
def.vtsay = struct('lags', 4);
def.varsbc2 = struct('ncoef', nc_nl);
def.vbds = struct('maxdim', 2, 'distance', 1.5);
def.vcumperiod = struct();
def.vspectrum = struct('smooth', 1, 'xlog', [false, true]);
def.varspectrum = struct('order', 16, 'nfreq', floor(n / 2), 'xlog', [false, true]);
links = struct( ...
    's', {{["plotband", "s"], ["vboxplot", "s"], ["vtboxplot", "s"], ["vident", "s"], ...
           ["vident2", "s"], ["stdmean", "s"], ["vboxcox", "group"]}}, ...
    'ncoef_acf', {{["vident", "ncoef"], ["vident2", "ncoef"], ["varsbc", "ncoef"]}}, ...
    'lags_unitroot', {{["adftest", "lags"], ["vphillips", "lags"], ["johansentest", "lags"]}}, ...
    'ncoef_nl', {{["nltests", "ncoef"], ["varsbc2", "ncoef"]}});
if isempty(varargin)
    return
end
if mod(numel(varargin), 2) ~= 0
    error('tsexplorer:options', ...
        'Options must be given as pairs, e.g. tooltest_defaults(y, "vident", struct(''ncoef'', 20)).');
end
out = def;
for k = 1:2:numel(varargin)
    tool = string(varargin{k});
    if ~isfield(def, tool)
        error('tsexplorer:options', "Unknown tool: %s", tool);
    end
    val = varargin{k + 1};
    onames = string(fieldnames(def.(tool)))';
    if isstruct(val)
        keys = string(fieldnames(val))';
        vals = struct2cell(val)';
    else
        if ~iscell(val)
            val = {val};
        end
        if numel(val) > numel(onames)
            error('tsexplorer:options', "Unknown option for %s: %d", tool, numel(onames) + 1);
        end
        keys = onames(1:numel(val));
        vals = val;
    end
    for j = 1:numel(keys)
        if ~ismember(keys(j), onames)
            error('tsexplorer:options', "Unknown option for %s: %s", tool, keys(j));
        end
        if ~isempty(vals{j})
            out.(tool).(keys(j)) = vals{j};
        end
    end
end
% propagate linked options (the last changed member of each group wins, in
% a fixed order)
groups = struct2cell(links);
for g = 1:numel(groups)
    changed = [];
    found = false;
    for mem = groups{g}
        mm = mem{1};
        if ~isequal(out.(mm(1)).(mm(2)), def.(mm(1)).(mm(2)))
            changed = out.(mm(1)).(mm(2));
            found = true;
        end
    end
    if found
        for mem = groups{g}
            mm = mem{1};
            out.(mm(1)).(mm(2)) = changed;
        end
    end
end
def = out;
end
