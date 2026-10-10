function out = tsx_auxsumstats(y, stats, nsimul)
%TSX_AUXSUMSTATS Bootstrap probability of zero mean (two sided: twice the
%   bootstrap probability of a statistic of the opposite sign).
%   The random numbers are those of MATLAB (not reproducible across
%   languages).
import tsexplorer.internal.*
n = size(y, 1);
m = size(y, 2);
bins = ceil(sqrt(n));
simul = nan(nsimul, m);
for i = 1:nsimul
    zi = y(randi(n, n, 1), :);
    simul(i, :) = mean(zi, 1, 'omitnan') ./ (tsx_sd(zi) / sqrt(n));
end
out = nan(m, 1);
for i = 1:m
    zi = simul(:, i);
    zi = zi(isfinite(zi));
    centers = tsx_hist(zi, bins).mids;
    lim = [floor(min(centers)), ceil(max(centers))];
    xaxis = tsx_seq_len(lim(1), lim(2), 181);
    fi = cumsum(tsx_ksdensity(zi, xaxis));
    fi = fi / max(fi);
    r = tsx_interpol(xaxis, fi, 0);
    if stats(i) < 0
        r = 1 - r;
    end
    out(i) = min(1, max(0, 2 * r));
end
end
