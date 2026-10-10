function out = tsx_smooth_triangular(x, smooth, even)
%TSX_SMOOTH_TRIANGULAR Triangular smoothing: centred moving average with
%   weights 1, 2, ..., (L + 1) / 2, ..., 2, 1 (normalised). X holds the
%   (cross) periodogram at the frequencies 2 pi j / T, j = 0, ..., floor(T/2).
%   At both ends the periodogram is extended by symmetry, I(-w) = conj(I(w))
%   and I(pi + w) = conj(I(pi - w)). EVEN indicates whether T is even (the
%   last frequency is then pi).
if nargin < 3
    even = true;
end
x = x(:);
if smooth <= 1
    out = x;
    return
end
if mod(smooth, 2) == 0
    smooth = smooth + 1;
end
inc = 2 / (smooth + 1);
half = tsexplorer.internal.tsx_seq_by(inc, 1 - inc / 2, inc);
b = [half, 1, fliplr(half)];
b = b / sum(b);
lb = (numel(b) - 1) / 2;
n = numel(x);
if lb > n - 2
    error('tsexplorer:smooth', "The smoothing window is too long for the sample size.");
end
left = conj(flipud(x(2:(lb + 1))));
if even
    right = conj(x((n - 1):-1:(n - lb)));
else
    right = conj(x(n:-1:(n - lb + 1)));
end
xp = [left; x; right];
out = x;
bb = fliplr(b);
for k = 1:n
    out(k) = sum(bb(:) .* xp(k:(k + 2 * lb)));
end
end
