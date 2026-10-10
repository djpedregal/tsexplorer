function [hist, density] = tsx_hist_data(z, bins)
%TSX_HIST_DATA Histogram, normal density and kernel density (tables).
import tsexplorer.internal.*
z = z(~isnan(z));
z = z(:);
n = numel(z);
h = tsx_hist(z, bins);
rz = max(z) - min(z);
xaxis = tsx_seq_len(min(h.breaks), max(h.breaks), 181)';
normal = n * tsx_dnorm((xaxis - mean(z)) / tsx_sd(z)) / tsx_sd(z) * (rz / bins);
kern = tsx_ksdensity(z, xaxis) * rz * n / bins;
hist = table(h.mids(:), h.breaks(1:end - 1)', h.breaks(2:end)', h.counts(:), ...
    'VariableNames', {'mid', 'lower', 'upper', 'count'});
density = table(xaxis, normal, kern, 'VariableNames', {'x', 'normal', 'kernel'});
end
