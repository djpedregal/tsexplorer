function s = tsx_format_g(x, sig)
%TSX_FORMAT_G Number with SIG significant digits as C's "%.<sig>g" (the
%   same in R's sprintf and MATLAB's sprintf except for the exponent, which
%   has at least two digits in both).
s = string(sprintf('%.*g', sig, x));
end
