function r = vbds(y, opts)
%VBDS BDS test of independence.
%   Brock, Dechert and Scheinkman (BDS) test of the null hypothesis that a
%   series is independent and identically distributed, for embedding
%   dimensions 2:maxdim. P-values are asymptotic (standard normal).
%
%   R = vbds(Y)
%   R = vbds(Y, maxdim=2, distance=1.5, names=[])
%
%   Arguments:
%     Y         Time series data (see as_tsx_matrix).
%     maxdim    Maximum embedding dimension (at least 2). Default 2.
%     distance  Dimensional distance as a fraction of the standard
%               deviation of each series. Default 1.5. It is reduced to
%               min(0.9 * (max(y) - mean(y)) / sd(y)) (minimum over the
%               series) if larger than that.
%     names     Optional names of the series.
%
%   Details:
%     The computations follow the implementation of Ludwig Kanzler (1998),
%     rewritten without the bitwise storage that program uses to save
%     memory.
%
%   Value:
%     A struct of class ["tsx_vbds" "tsx_result"] with fields call
%     (effective maxdim and distance), series and table, a table with
%     columns series, dim, w (BDS statistic) and p_value.
%
%   References:
%     Brock, W.A., Dechert, W.D., Scheinkman, J.A. and LeBaron, B. (1996).
%     A test for independence based on the correlation dimension.
%     Econometric Reviews, 15, 197-235.
%     Kanzler, L. (1999). Very fast and correctly sized estimation of the
%     BDS statistic. Working paper, University of Oxford.
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.print(vbds(vdif(log(y), [1 1], [1 12]), maxdim=4))
%
%   See also tsexplorer.print, nltests, vtsay.
arguments
    y
    opts.maxdim = 2
    opts.distance = 1.5
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
maxdim = min(tsx_check_int(opts.maxdim, "maxdim", 2), floor(n / 2));
% the limit is expressed, as 'distance', in standard deviations
lim = 0.9 * (max(y, [], 1, 'omitnan') - mean(y, 1, 'omitnan')) ./ tsx_sd(y);
distance = min(opts.distance, min(lim));
tab = table();
for i = 1:size(y, 2)
    b = tsx_bds(y(~isnan(y(:, i)), i), maxdim, distance);
    k = maxdim - 1;
    tab = [tab; table(repmat(names(i), k, 1), (2:maxdim)', b.w(:), b.p_value(:), ...
        'VariableNames', {'series', 'dim', 'w', 'p_value'})]; %#ok<AGROW>
end
r = tsx_result("vbds", 'call', struct('maxdim', maxdim, 'distance', distance), ...
    'series', names, 'table', tab);
end
