function out = tsx_eps(x)
%TSX_EPS Spacing of floating point numbers: distance from abs(x) to the next
%   larger double (eps(x) in MATLAB, written out as in the R version).
x = abs(x);
out = repmat(2 ^ -1074, size(x));
nz = x > 0 & isfinite(x);
out(nz) = 2 .^ (floor(log2(x(nz))) - 52);
end
