function r = vgranger(y, opts)
%VGRANGER Granger causality tests.
%   Wald tests (F and chi-squared versions) of Granger non-causality on a
%   VAR model without constant estimated on the demeaned series.
%
%   R = vgranger(Y)
%   R = vgranger(Y, lags=[], tests=[], names=[])
%
%   Arguments:
%     Y        Time series data (see as_tsx_matrix), at least two
%              series.
%     lags     Lags of the VAR model (block constraints are possible, e.g.
%              [1 2 12]). Default 1:min(floor(sqrt(T)), 20). If the largest
%              lag exceeds T / 2, 1:2 is used.
%     tests    String array of tests (or a single blank-separated string).
%              Default: every pair of series in both directions. Invalid
%              tests are ignored.
%     names    Optional names of the series.
%
%   Details:
%     Each test is written with letters for the series (a is the first
%     one, b the second, ...): the letters before - are the equations and
%     the letters after - the possibly causing variables. For instance
%     "a-b" tests whether b causes a, and "ab-c" whether c causes a and b.
%
%   Value:
%     A struct of class ["tsx_vgranger" "tsx_result"] with fields call,
%     series and table, a table with columns test, h0, constraints, f, p_f,
%     chi2, p_chi2.
%
%   References:
%     Granger, C.W.J. (1969). Investigating causal relations by econometric
%     models and cross-spectral methods. Econometrica, 37, 424-438.
%
%   Examples:
%     y = load_data("lydia_pinkham");
%     tsexplorer.print(vgranger(vdif(log(y)), lags=1:3))
%
%   See also tsexplorer.print, varsbc, vident2.
arguments
    y
    opts.lags = []
    opts.tests = []
    opts.names = []
end
import tsexplorer.internal.*
[y, names] = as_tsx_matrix(y, names = opts.names);
n = size(y, 1);
m = size(y, 2);
if m < 2
    error('tsexplorer:vgranger', "'vgranger' needs at least two series.");
end
lags = opts.lags;
if isempty(lags)
    lags = 1:min(floor(sqrt(n)), 20);
end
lags = round(lags(:)');
if max(lags) > n / 2
    lags = 1:2;
end
nlags = numel(lags);
tests = tsx_granger_tests(opts.tests, m);
z = y - mean(y, 1, 'omitnan');
v = tsx_mvar(z, lags, false);
pt = -v.p';
beta = pt(:);
vbeta = kron(v.inv_xx, v.sigma);
npar = m * m * nlags;
nt = numel(tests);
h0 = strings(nt, 1);
[constraints, f, p_f, chi2, p_chi2] = deal(nan(nt, 1));
for k = 1:nt
    parts = split(tests(k), "-");
    eqs = double(char(parts(1))) - 96;
    causes = double(char(parts(2))) - 96;
    nconst = numel(causes) * numel(eqs) * nlags;
    cm = zeros(nconst, npar);
    row = 1;
    for ci = causes
        for ei = eqs
            for l = 1:nlags
                cm(row, (ci - 1) * m + ei + (l - 1) * m * m) = 1;
                row = row + 1;
            end
        end
    end
    cb = cm * beta;
    w = cb' * ((cm * vbeta * cm') \ cb);
    df2 = n * m - npar + m * m;
    constraints(k) = nconst;
    f(k) = w / nconst;
    p_f(k) = tsx_pf(w / nconst, nconst, df2, false);
    chi2(k) = w;
    p_chi2(k) = tsx_pchisq(w, nconst, false);
    if numel(causes) > 1
        verb = "do";
    else
        verb = "does";
    end
    h0(k) = tsx_and_list(names(causes)) + " " + verb + " not cause " + tsx_and_list(names(eqs));
end
test = tests(:);
tab = table(test, h0, constraints, f, p_f, chi2, p_chi2);
r = tsx_result("vgranger", 'call', struct('lags', lags, 'tests', tests), ...
    'series', names, 'table', tab);
end
