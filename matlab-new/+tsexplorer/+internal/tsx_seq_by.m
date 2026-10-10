function x = tsx_seq_by(from, to, by)
%TSX_SEQ_BY Values from FROM to TO with increment BY, computed as
%   seq(from, to, by = by) in R: from + (0:n) * by, n = floor((to - from) /
%   by + 1e-10), clamped to TO.
n = floor((to - from) / by + 1e-10);
x = from + (0:n) * by;
if by > 0
    x = min(x, to);
else
    x = max(x, to);
end
end
