function r = vident2(y, opts)
%VIDENT2 Multivariate sample autocorrelation functions.
%   Sample autocorrelation matrices and partial lag autocorrelation
%   matrices (Heyse and Wei, 1985) or partial autoregression matrices (Tiao
%   and Box, 1981) of a vector of time series, together with the
%   information criteria, the likelihood ratio statistic of adding one lag
%   to a VAR model and a multivariate portmanteau test.
%
%   R = vident2(Y)
%   R = vident2(Y, ncoef=[], s=12, npar=0, type=0, names=[])
%   tsexplorer.plot(R, series=S)
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix), at least two
%              series.
%     ncoef    Number of lags. Default min(38, ceil(T / 4 / m * 2)).
%     s        Seasonal period (only for plots).
%     npar     Number of estimated parameters (if Y are residuals); the
%              degrees of freedom of the portmanteau test are
%              m^2 (lag - npar).
%     type     0 for partial lag autocorrelation matrices, 1 for partial
%              autoregression matrices.
%     names    Optional names of the series.
%     S        For the plot, one series (index or name) to plot its ACF and
%              partial function, or two series to plot their cross
%              correlations.
%
%   Value:
%     A struct of class ["tsx_vident2" "tsx_result"] with fields
%     * call, series,
%     * acf, se_acf, pacf, se_pacf: arrays m x m x (ncoef + 1) for lags
%       0:ncoef. Element (a, b, k + 1) is the correlation between series a
%       at time t and series b at time t - k. At lag 0 the partial matrices
%       repeat the correlation matrix,
%     * stats: table with columns lag, aic, sbc, chi, p_chi (likelihood
%       ratio test of a VAR(lag) against a VAR(lag - 1)), p_q (multivariate
%       portmanteau test of Hosking (1980) with the correction of Li and
%       McLeod (1981), T sum_k tr(R_k' R_0^-1 R_k R_0^-1) +
%       m^2 k (k + 1) / (2T)) and det_sigma.
%
%   References:
%     Tiao, G.C. and Box, G.E.P. (1981). Modeling multiple time series with
%     applications. Journal of the American Statistical Association, 76,
%     802-816.
%     Heyse, J.F. and Wei, W.W.S. (1985). The partial lag autocorrelation
%     function. Technical Report 32, Temple University.
%     Hosking, J.R.M. (1980). The multivariate portmanteau statistic.
%     Journal of the American Statistical Association, 75, 602-608.
%     Li, W.K. and McLeod, A.I. (1981). Distribution of the residual
%     autocorrelations in multivariate ARMA time series models. Journal of
%     the Royal Statistical Society B, 43, 231-239.
%
%   Examples:
%     y = load_data("lydia_pinkham");
%     r = vident2(vdif(log(y)), ncoef=8);
%     tsexplorer.print(r)
%     tsexplorer.plot(r, series=[1 2])
%
%   See also tsexplorer.print, tsexplorer.plot, vident,
%   varsbc.
arguments
    y
    opts.ncoef = []
    opts.s = 12
    opts.npar = 0
    opts.type = 0
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
if m < 2
    error('tsexplorer:vident2', "'vident2' needs at least two series.");
end
ncoef = opts.ncoef;
if isempty(ncoef)
    ncoef = min(38, ceil(n / 4 / m * 2));
end
ncoef = min([tsx_check_int(ncoef, "ncoef"), n - 5, n - 3]);
npar = opts.npar;
type = opts.type;
miss = any(isnan(y(:)));
zs = tsx_standardize(y);
z = y - mean(y, 1, 'omitnan');
det_sa = det(z' * z / n);
acf = zeros(m, m, ncoef + 1);
pacf = nan(m, m, ncoef + 1);
se_acf = zeros(m, m, ncoef + 1);
se_pacf = nan(m, m, ncoef + 1);
r0 = tsx_nancov(zs);
r0i = inv(r0);
acf(:, :, 1) = r0;
pacf(:, :, 1) = r0;
se_acf(:, :, 1) = 1 / sqrt(n);
se_pacf(:, :, 1) = 1 / sqrt(n);
ss = sqrt(sum(z .^ 2, 1));
for k = 1:ncoef
    if miss
        [p, np] = tsx_nanprod(zs((k + 1):n, :)', zs(1:(n - k), :));
        acf(:, :, k + 1) = p ./ np;
    else
        acf(:, :, k + 1) = (z((k + 1):n, :)' * z(1:(n - k), :)) ./ (ss' * ss);
    end
    se_acf(:, :, k + 1) = 1 / sqrt(n - k);
end
if type == 0
    se_pacf(:, :, 2:end) = 1 / sqrt(n);
    pacf(:, :, 2) = acf(:, :, 2);
end
lag = (1:ncoef)';
[aic, sbc, chi, p_q, det_sigma] = deal(nan(ncoef, 1));
cumtr = 0;
for i = 1:ncoef
    v = tsx_mvar(z, 1:i, true);
    if type == 1
        idx = ((i - 1) * m + 1):(i * m);
        pacf(:, :, i + 1) = v.p(idx, :)';
        se_pacf(:, :, i + 1) = v.se_p(idx, :)';
    elseif i < ncoef
        vb = tsx_mvar(z, 1:i, true, true);
        u = v.e((size(v.e, 1) - size(vb.e, 1) + 1):end, :);
        cr = tsx_nancorr([u, vb.e]);
        pacf(:, :, i + 2) = cr(1:m, (m + 1):(2 * m));
    end
    det_s = det(v.sigma);
    aic(i) = v.aic;
    sbc(i) = v.sbc;
    chi(i) = -(n - i - 1 - 0.5 - m * i) * log(det_s / det_sa);
    det_sigma(i) = det_s;
    det_sa = det_s;
    rk = acf(:, :, i + 1);
    cumtr = cumtr + trace(rk' * r0i * rk * r0i);
    q = n * cumtr + m * m * i * (i + 1) / 2 / n;
    if i > npar
        p_q(i) = tsx_pchisq(q, m * m * (i - npar), false);
    end
end
p_chi = tsx_pchisq(chi, m * m, false);
st = table(lag, aic, sbc, chi, p_chi, p_q, det_sigma);
r = tsx_result("vident2", ...
    'call', struct('ncoef', ncoef, 's', opts.s, 'npar', npar, 'type', type), ...
    'series', names, 'acf', acf, 'se_acf', se_acf, 'pacf', pacf, 'se_pacf', se_pacf, ...
    'stats', st);
end
