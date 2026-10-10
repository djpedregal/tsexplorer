function tsxt_expect_ref(tc, object, expected, tol)
%TSXT_EXPECT_REF Compare numbers ignoring names and dimensions, as
%   expect_ref() / expect_equal() of the R tests (all.equal semantics: the
%   missing values must be in the same positions and the mean relative
%   difference of the rest must be <= TOL, default 1e-6; the absolute
%   difference when the mean of the expected values is <= TOL).
if nargin < 4
    tol = 1e-6;
end
a = tonum(object);
b = tonum(expected);
tc.verifyEqual(numel(a), numel(b), "Different number of values.");
if numel(a) ~= numel(b)
    return
end
tc.verifyEqual(isnan(a), isnan(b), "Missing values in different positions.");
ok = ~isnan(a) & ~isnan(b);
if ~any(ok)
    return
end
inf_ok = isinf(a(ok)) | isinf(b(ok));
tc.verifyEqual(a(ok & isinf(a)), b(ok & isinf(a)), "Different infinite values.");
x = a(ok);
y = b(ok);
x = x(~inf_ok);
y = y(~inf_ok);
if isempty(y)
    return
end
xy = mean(abs(y - x));
xn = mean(abs(y));
if isfinite(xn) && xn > tol
    xy = xy / xn;
end
tc.verifyLessThanOrEqual(xy, tol, sprintf("Mean relative difference %g > %g.", xy, tol));
end

function v = tonum(x)
if istable(x)
    x = table2array(x);
end
if isstruct(x)
    x = cell2mat(struct2cell(x));
end
v = double(x(:));
end
