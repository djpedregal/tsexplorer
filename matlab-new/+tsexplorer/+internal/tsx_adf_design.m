function [yy, x] = tsx_adf_design(z, p)
%TSX_ADF_DESIGN Design of the ADF regressions with P lagged differences:
%   columns z(t-1), constant, trend, dz(t-1), ..., dz(t-p). Rows with
%   missing values are removed.
z = z(:);
n = numel(z);
dz = diff(z);
rows = ((p + 2):n)';
x = [z(rows - 1), ones(numel(rows), 1), (1:numel(rows))'];
for j = 1:p
    x = [x, dz(rows - 1 - j)]; %#ok<AGROW>
end
yy = z(rows);
ok = all(~isnan(x), 2) & ~isnan(yy);
yy = yy(ok);
x = x(ok, :);
end
