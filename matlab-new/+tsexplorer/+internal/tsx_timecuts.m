function cuts = tsx_timecuts(timecuts, n)
%TSX_TIMECUTS Subsamples of testhet (first and last observation in each
%   row; columns start and end).
if isempty(timecuts)
    timecuts = [floor(n / 3), floor(2 * n / 3) + 2];
end
if isvector(timecuts)
    tc = sort(timecuts(:));
    tc = tc(~(tc < 5 | tc > n - 5));
    if isempty(tc)
        cuts = default_cuts(n);
        return
    end
    cuts = [[1; tc + 1], [tc; n]];
else
    cuts = sort(timecuts, 2);
    [~, o] = sort(cuts(:, 1));
    cuts = cuts(o, :);
    drop = [find(cuts(2:end, 1) < 5) + 1; find(cuts(:, 1) > n - 5)];
    cuts(unique(drop), :) = [];
    drop = find(diff(cuts(:, 2)) < 0) + 1;
    cuts(drop, :) = [];
    drop = find((cuts(2:end, 1) - cuts(1:end - 1, 2)) < 0) + 1;
    cuts(drop, :) = [];
end
if size(cuts, 1) < 2
    cuts = default_cuts(n);
end
cuts = double(cuts);
end

function cuts = default_cuts(n)
i1 = floor(n / 3);
i2 = floor(2 * n / 3) + 2;
cuts = [1, i1; i1 + 1, i2; i2 + 1, n];
end
