function r = testhet(y, opts)
%TESTHET Heteroskedasticity tests.
%   Variance ratio F tests between non-overlapping subsamples of each
%   series.
%
%   R = testhet(Y)
%   R = testhet(Y, timecuts=[], names=[])
%
%   Arguments:
%     Y         Time series data (see as_tsx_matrix).
%     timecuts  Definition of the subsamples:
%               * a vector of n cut points divides the sample into n + 1
%                 consecutive subsamples (cut points closer than 5
%                 observations to the ends are discarded),
%               * a n x 2 matrix gives the first and last observation of
%                 each subsample (overlapping or invalid rows are
%                 discarded).
%               If no valid subsamples remain, the sample is split into
%               three parts. Default [floor(T / 3), floor(2 * T / 3) + 2].
%     names     Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_testhet" "tsx_result"] with fields call,
%     series, samples (matrix with first and last observation of each
%     subsample) and table, a table with columns series, start1, end1,
%     start2, end2, f (ratio of variances, always <= 1) and p_value (two
%     sided).
%
%   Examples:
%     y = load_data("airpas");
%     tsexplorer.print(testhet(y))
%     tsexplorer.print(testhet(log(y), timecuts=[48 96]))
%     tsexplorer.print(testhet(y, timecuts=[1 30; 50 90; 100 144]))
%
%   See also tsexplorer.print, vcusum, stdmean.
arguments
    y
    opts.timecuts = []
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
cuts = tsx_timecuts(opts.timecuts, n);
series = strings(0, 1);
[start1, end1, start2, end2, f, p_value] = deal(zeros(0, 1));
for s = 1:size(y, 2)
    for i = 1:(size(cuts, 1) - 1)
        for j = (i + 1):size(cuts, 1)
            zi = y(cuts(i, 1):cuts(i, 2), s);
            zj = y(cuts(j, 1):cuts(j, 2), s);
            fij = tsx_sd(zi) ^ 2 / tsx_sd(zj) ^ 2;
            d1 = sum(~isnan(zi)) - 1;
            d2 = sum(~isnan(zj)) - 1;
            if fij > 1
                fij = 1 / fij;
                [d1, d2] = deal(d2, d1);
            end
            series(end + 1, 1) = names(s); %#ok<AGROW>
            start1(end + 1, 1) = cuts(i, 1); %#ok<AGROW>
            end1(end + 1, 1) = cuts(i, 2); %#ok<AGROW>
            start2(end + 1, 1) = cuts(j, 1); %#ok<AGROW>
            end2(end + 1, 1) = cuts(j, 2); %#ok<AGROW>
            f(end + 1, 1) = fij; %#ok<AGROW>
            p_value(end + 1, 1) = 2 * tsx_pf(fij, d1, d2); %#ok<AGROW>
        end
    end
end
tab = table(series, start1, end1, start2, end2, f, p_value);
r = tsx_result("testhet", 'call', struct('timecuts', opts.timecuts), 'series', names, ...
    'samples', cuts, 'table', tab);
end
