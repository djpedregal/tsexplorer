function h = tsx_hist(x, bins)
%TSX_HIST Histogram counts with BINS equally spaced bins between min and max
%   (as the function hist). Fields: breaks, counts, mids (row vectors).
x = x(~isnan(x));
mn = min(x);
mx = max(x);
if mn == mx
    mn = mn - bins / 2;
    mx = mx + bins / 2;
end
breaks = tsexplorer.internal.tsx_seq_len(mn, mx, bins + 1);
counts = zeros(1, bins);
for k = 1:numel(x)
    % interval [b(j), b(j + 1)), the last one closed; values outside are
    % assigned to the first or last bin
    j = find(breaks <= x(k), 1, 'last');
    if isempty(j)
        j = 1;
    end
    j = min(j, bins);
    counts(j) = counts(j) + 1;
end
h = struct('breaks', breaks, 'counts', counts, ...
    'mids', (breaks(2:end) + breaks(1:end - 1)) / 2);
end
