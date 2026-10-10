function lags = tsx_unitroot_lags(lags, n, m)
%TSX_UNITROOT_LAGS Default and correction of the lags of the unit root tests
%   (adftest, vphillips, johansentest). Row vector.
if isempty(lags)
    if m == 1
        lags = 1:min(floor(sqrt(n)), 20);
    else
        lags = min(floor(sqrt(n)), 20);
    end
end
lags = round(double(lags(:)'));
if max(lags) > n / 2
    lags = floor(n / 2);
end
end
