function r = varsbc2(y, opts)
%VARSBC2 Non-linearity test based on the Schwarz criterion of squares.
%   Schwarz information criterion of AR models of orders 0:ncoef fitted to
%   the squares of the series. A minimum at order 0 suggests linearity.
%
%   R = varsbc2(Y)
%   R = varsbc2(Y, ncoef=[], series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     ncoef    Maximum order. Default min(38, ceil(sqrt(T))), limited to
%              T - 3.
%     series   Series to analyse (index or name).
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_varsbc2" "tsx_result"] with fields call,
%     series, table (table with columns lag and sbc), best (order with
%     minimum SBC) and linear (true when best is 0).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.plot(varsbc2(vdif(log(y), [1 1], [1 12])))
%
%   See also tsexplorer.plot, varsbc, nltests.
arguments
    y
    opts.ncoef = []
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
ncoef = opts.ncoef;
if isempty(ncoef)
    ncoef = min(38, ceil(sqrt(n)));
end
ncoef = min(tsx_check_int(ncoef, "ncoef", 0), n - 3);
i = tsx_series_index(opts.series, names);
i = i(1);
z2 = y(:, i) .^ 2;
zm = z2 - mean(z2, 'omitnan');
sbc = zeros(ncoef + 1, 1);
for k = 0:ncoef
    sbc(k + 1) = tsx_auxvarsbc(zm, k).sbc;
end
[~, ib] = min(sbc);
best = ib - 1;
r = tsx_result("varsbc2", 'call', struct('ncoef', ncoef, 'series', i), ...
    'series', names(i), 'table', table((0:ncoef)', sbc, 'VariableNames', {'lag', 'sbc'}), ...
    'best', best, 'linear', best == 0);
end
