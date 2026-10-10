function r = tsx_acf_pacf(x, ncoef, npar)
%TSX_ACF_PACF Sample ACF, PACF, Ljung-Box and Monti tests of one series
%   (common core of vident() and nltests()). Fields: sacf, spacf, se_acf,
%   se_pacf, q, p_q, q_mt, p_q_mt (column vectors).
import tsexplorer.internal.*
if nargin < 3
    npar = 0;
end
x = x(:);
n = numel(x);
zs = tsx_standardize(x);
sacf = zeros(ncoef, 1);
if ~any(isnan(zs))
    den = sum(zs .^ 2);
    for k = 1:ncoef
        sacf(k) = sum(zs(1:(n - k)) .* zs((1 + k):n)) / den;
    end
else
    for k = 1:ncoef
        pr = zs((k + 1):n) .* zs(1:(n - k));
        sacf(k) = sum(pr, 'omitnan') / sum(~isnan(pr));
    end
end
seacf = zeros(ncoef, 1);
seacf(1) = 1 / sqrt(n);
if ncoef > 1
    seacf(2:ncoef) = sqrt((1 + 2 * cumsum(sacf(1:(ncoef - 1)) .^ 2)) / n);
end
spacf = tsx_durbin_levinson(sacf);
sepacf = repmat(1 / sqrt(n), ncoef, 1);
lags = (1:ncoef)';
df = lags - npar;
q = n * (n + 2) * cumsum(sacf .^ 2 ./ (n - lags));
qmt = n * (n + 2) * cumsum(spacf .^ 2 ./ (n - lags));
pq = nan(ncoef, 1);
pqmt = nan(ncoef, 1);
ok = df > 0;
pq(ok) = tsx_pchisq(q(ok), df(ok), false);
pqmt(ok) = tsx_pchisq(qmt(ok), df(ok), false);
r = struct('sacf', sacf, 'spacf', spacf, 'se_acf', seacf, 'se_pacf', sepacf, ...
    'q', q, 'p_q', pq, 'q_mt', qmt, 'p_q_mt', pqmt);
end
