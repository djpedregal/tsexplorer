function r = vboxcox(y, opts)
%VBOXCOX Box-Cox transformation.
%   Estimates the Box-Cox parameter lambda of each series with the method
%   of Guerrero (1993): the series is divided into groups of 'group'
%   consecutive observations and lambda minimises the coefficient of
%   variation of s_j / mean_j^(1 - lambda) (standard deviation over mean of
%   each group). It also evaluates, over a grid of values of lambda
%   (axislambdas), the standard deviation, the mean over standard deviation
%   and the criterion of the transformed series, and returns the
%   transformed data.
%
%   R = vboxcox(Y)
%   R = vboxcox(Y, lambdas=[], group=12, axislambdas=-1:0.1:1,
%                          series=1, names=[])
%
%   Arguments:
%     Y            Time series data (see as_tsx_matrix).
%     lambdas      Optional values of lambda for the transformation of each
%                  series (the last one is repeated for the remaining
%                  series). If [] they are estimated.
%     group        Number of observations per group (usually the seasonal
%                  period). Default 12.
%     axislambdas  Grid of lambda values for the plot.
%     series       Series used for the grid evaluation and the plot.
%     names        Optional names of the series.
%
%   Details:
%     Series with non-positive values are shifted by abs(min) + 1e-4
%     before the transformation. The minimum is found with the Nelder-Mead
%     simplex method.
%
%   Value:
%     A struct of class ["tsx_vboxcox" "tsx_result"] with fields call,
%     series, lambdas (estimated or supplied, one per series), estimated
%     (logical), transformed (matrix of transformed series) and grid, a
%     table for the selected series with columns lambda, sd, mean_sd,
%     criterion (minus the coefficient of variation), and their
%     standardised versions sd_std, mean_sd_std, criterion_std (as
%     plotted; [] if axislambdas is empty).
%
%   References:
%     Box, G.E.P. and Cox, D.R. (1964). An analysis of transformations.
%     Journal of the Royal Statistical Society B, 26, 211-252.
%     Guerrero, V.M. (1993). Time-series analysis supported by power
%     transformations. Journal of Forecasting, 12, 37-48.
%
%   Examples:
%     r = vboxcox(load_data("airpas"));
%     r.lambdas
%     tsexplorer.plot(r)
%
%   See also tsexplorer.print, tsexplorer.plot, stdmean.
arguments
    y
    opts.lambdas = []
    opts.group = 12
    opts.axislambdas = tsexplorer.internal.tsx_seq_by(-1, 1, 0.1)
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
m = size(y, 2);
group = tsx_check_int(opts.group, "group", 2);
shifted = y;
for i = 1:m
    shifted(:, i) = tsx_boxcox_shift(y(:, i));
end
lambdas = opts.lambdas;
estimated = isempty(lambdas);
if estimated
    lambdas = zeros(1, m);
    for i = 1:m
        zi = shifted(:, i);
        lambdas(i) = tsx_fminsearch(@(l) tsx_guerrero(l, zi, group), 1).par;
    end
else
    lambdas = double(lambdas(1:min(numel(lambdas), m)));
    lambdas = [lambdas(:)', repmat(lambdas(end), 1, m - numel(lambdas))];
end
tr = shifted;
for i = 1:m
    tr(:, i) = tsx_boxcox(shifted(:, i), lambdas(i));
end
i = tsx_series_index(opts.series, names);
i = i(1);
ax = opts.axislambdas;
grid = [];
if ~isempty(ax)
    zi = shifted(:, i);
    ax = ax(:);
    [sd, mean_sd, criterion] = deal(nan(numel(ax), 1));
    for j = 1:numel(ax)
        zt = tsx_boxcox(zi, ax(j));
        sd(j) = tsx_sd(zt);
        mean_sd(j) = mean(zt, 'omitnan') / sd(j);
        criterion(j) = -tsx_guerrero(ax(j), zi, group);
    end
    std = tsx_standardize([sd, mean_sd, criterion]);
    grid = table(ax, sd, mean_sd, criterion, std(:, 1), std(:, 2), std(:, 3), ...
        'VariableNames', {'lambda', 'sd', 'mean_sd', 'criterion', 'sd_std', 'mean_sd_std', ...
                          'criterion_std'});
end
r = tsx_result("vboxcox", 'call', struct('group', group, 'axislambdas', opts.axislambdas, ...
    'series', i), 'series', names, 'lambdas', lambdas, 'estimated', estimated, ...
    'transformed', tr, 'grid', grid);
end
