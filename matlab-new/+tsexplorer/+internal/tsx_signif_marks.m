function out = tsx_signif_marks(x, lim)
%TSX_SIGNIF_MARKS Marks "+" (> lim), "-" (< -lim), "." otherwise and "@" for
%   NaN (default lim = 2), with the size of X.
if nargin < 2
    lim = 2;
end
out = repmat(".", size(x));
out(x > lim) = "+";
out(x < -lim) = "-";
out(isnan(x)) = "@";
end
