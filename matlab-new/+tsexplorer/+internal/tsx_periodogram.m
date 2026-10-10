function per = tsx_periodogram(z, w)
%TSX_PERIODOGRAM Periodogram ordinates 2/T |sum z_t exp(-i w t)|^2 (missing
%   values skipped).
z = z(:);
n = numel(z);
tt = (1:n)';
ok = ~isnan(z);
per = zeros(size(w));
for j = 1:numel(w)
    a = sum(z(ok) .* cos(w(j) * tt(ok)));
    b = sum(z(ok) .* sin(w(j) * tt(ok)));
    per(j) = 2 / n * (a ^ 2 + b ^ 2);
end
end
