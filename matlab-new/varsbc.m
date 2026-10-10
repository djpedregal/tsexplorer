function r = varsbc(y, opts)
%VARSBC Information criteria of AR and VAR models.
%   Corrected Akaike (AICc), Schwarz (SBC) and Hannan-Quinn (HQC)
%   information criteria of AR (one series) or VAR (several series) models
%   of orders 0:ncoef, and the likelihood ratio test of each order against
%   the previous one.
%
%   R = varsbc(Y)
%   R = varsbc(Y, ncoef=[], series=1, names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix).
%     ncoef    Maximum order. Default min(38, ceil(T / 4 / m * 2)), limited
%              to T - 3.
%     series   Series to analyse: one series (index or name) for AR models,
%              several or "all" for a VAR model.
%     names    Optional names of the series.
%
%   Value:
%     A struct of class ["tsx_varsbc" "tsx_result"] with fields call,
%     series (series analysed), table (table with columns lag, aicc, sbc,
%     hqc, chi, p_chi) and best (struct with the order minimising each
%     criterion: aicc, sbc, hqc).
%
%   References:
%     Lutkepohl, H. (2005). New Introduction to Multiple Time Series
%     Analysis. Springer.
%
%   Examples:
%     y = load_data("airpas");
%     r = varsbc(vdif(log(y), [1 1], [1 12]), ncoef=15);
%     tsexplorer.print(r)
%     tsexplorer.plot(r)
%
%   See also tsexplorer.print, tsexplorer.plot, vident2,
%   varsbc2.
arguments
    y
    opts.ncoef = []
    opts.series = 1
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
ncoef = opts.ncoef;
if isempty(ncoef)
    ncoef = min(38, ceil(n / 4 / m * 2));
end
ncoef = min(tsx_check_int(ncoef, "ncoef", 0), n - 3);
sel = tsx_series_index(opts.series, names, true);
k = numel(sel);
zm = y(:, sel) - mean(y(:, sel), 1, 'omitnan');
det_sa = det(zm' * zm / n);
lag = (0:ncoef)';
[aicc, sbc, hqc, chi] = deal(nan(ncoef + 1, 1));
for i = 0:ncoef
    a = tsx_auxvarsbc(zm, i);
    aicc(i + 1) = a.aicc;
    sbc(i + 1) = a.sbc;
    hqc(i + 1) = a.hqc;
    det_s = det(a.sigma);
    chi(i + 1) = -(n - i - 1 - 0.5 - k * i) * log(det_s / det_sa);
    det_sa = det_s;
end
p_chi = tsx_pchisq(chi, k * k, false);
chi(1) = NaN;
p_chi(1) = NaN;
tab = table(lag, aicc, sbc, hqc, chi, p_chi);
[~, ia] = min(aicc);
[~, is] = min(sbc);
[~, ih] = min(hqc);
best = struct('aicc', ia - 1, 'sbc', is - 1, 'hqc', ih - 1);
r = tsx_result("varsbc", 'call', struct('ncoef', ncoef, 'series', sel), ...
    'series', names(sel), 'table', tab, 'best', best);
end
