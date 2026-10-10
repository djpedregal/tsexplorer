function p = adfcritical(x, n, table)
%ADFCRITICAL Approximate p-values of Dickey-Fuller statistics.
%   Interpolates the p-value of Dickey-Fuller t and F statistics in the
%   tables of Fuller (1976) and Dickey and Fuller (1981). The tables are
%   the points (critical value, sample size) with known p-values; the
%   p-value of a statistic is interpolated linearly on a Delaunay
%   triangulation of those points (barycentric coordinates of the triangle
%   that contains the statistic and the sample size). Sample sizes below
%   25 are taken as 25 and sizes above 500 use the asymptotic row. Outside
%   the tables the p-value is set to 0 or 1.
%
%   P = adfcritical(X, N, TABLE)
%
%   Arguments:
%     X        Vector of statistics.
%     N        Sample size.
%     TABLE    One of "t_none", "t_const", "t_trend" (t statistics without
%              deterministic terms, with constant, with constant and
%              trend), "f_const" (Phi1) or "f_trend" (Phi3).
%
%   Value:
%     Vector of p-values (the size of X).
%
%   References:
%     Fuller, W.A. (1976). Introduction to Statistical Time Series. Wiley.
%     Dickey, D.A. and Fuller, W.A. (1981). Likelihood ratio statistics for
%     autoregressive time series with a unit root. Econometrica, 49,
%     1057-1072.
%
%   Examples:
%     adfcritical([-3.5 -2 0], 100, "t_const")
%
%   See also adftest, vphillips.
arguments
    x
    n (1, 1) double
    table (1, 1) string {mustBeMember(table, ["t_none", "t_const", "t_trend", ...
        "f_const", "f_trend"])}
end
import tsexplorer.internal.*
tabs = tsx_tables();
tab = tabs.adf.(table);
sizes = tabs.adf_sizes;
is_t = startsWith(table, "t");
if is_t
    pr = tabs.adf_p_t;
else
    pr = tabs.adf_p_f;
end
if n > 500
    n = 1000;
end
if n < 25
    n = 25;
end
% points (critical value, sample size, probability) in column-major order
px = tab(:);
py = repmat(sizes(:), numel(pr), 1);
pp = repelem(pr(:), numel(sizes));
tri = tabs.adf_tri.(table);
p = nan(size(x));
for k = 1:numel(x)
    xi = x(k);
    if isnan(xi)
        continue
    end
    v = tsx_tri_interp(px, py, pp, tri, xi, n);
    if isnan(v)
        if is_t
            v = double(xi > -0.5);
        else
            v = double(~(xi > 4));
        end
    end
    p(k) = v;
end
end
