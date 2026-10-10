function [out, w] = tsx_mspectrum(z)
%TSX_MSPECTRUM Periodogram matrices I(:, :, j) = conj(F_j) F_j.' / (2 pi T)
%   at the Fourier frequencies w_j = 2 pi j / T, j = 0, ..., floor(T / 2).
%   Missing values are skipped in the discrete Fourier transform. W is a
%   column vector.
if isvector(z)
    z = z(:);
end
n = size(z, 1);
m = size(z, 2);
nw = floor(n / 2) + 1;
w = 2 * pi * (0:(nw - 1))' / n;
tt = (1:n)';
f = complex(zeros(m, nw));
for k = 1:m
    ok = ~isnan(z(:, k));
    for j = 1:nw
        f(k, j) = sum(z(ok, k) .* exp(-1i * w(j) * (tt(ok) - 1)));
    end
end
out = complex(zeros(m, m, nw));
for j = 1:nw
    out(:, :, j) = conj(f(:, j)) * f(:, j).';
end
for k = 1:m
    out(k, k, :) = real(out(k, k, :));
end
out = out / (2 * pi * n);
end
