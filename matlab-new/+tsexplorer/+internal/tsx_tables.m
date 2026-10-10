function t = tsx_tables()
%TSX_TABLES Tables of critical values (R/sysdata.rda in the R version), read
%   once from the CSV files in data/tables (copies of
%   r/inst/extdata/tables). Fields: adf_sizes, adf_p_t, adf_p_f, adf,
%   adf_tri, joh_p, joh, lillie_p, lillie_n, lillie.
persistent cache
if ~isempty(cache)
    t = cache;
    return
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
dir = fullfile(root, 'data', 'tables');
opts = {'TextType', 'string', 'Delimiter', ','};

adf = readtable(fullfile(dir, 'adf_critical.csv'), opts{:});
t.adf_sizes = unique(adf.size, 'stable')';
names = unique(adf.table, 'stable');
t.adf = struct();
for k = 1:numel(names)
    rows = adf.table == names(k);
    p = unique(adf.p(rows), 'stable')';
    if startsWith(names(k), "t")
        t.adf_p_t = p;
    else
        t.adf_p_f = p;
    end
    % rows = sample sizes, columns = probabilities
    t.adf.(names(k)) = reshape(adf.value(rows), numel(t.adf_sizes), numel(p));
end

tri = readtable(fullfile(dir, 'adf_triangulation.csv'), opts{:});
t.adf_tri = struct();
for k = 1:numel(names)
    rows = tri.table == names(k);
    t.adf_tri.(names(k)) = [tri.v1(rows), tri.v2(rows), tri.v3(rows)];
end

joh = readtable(fullfile(dir, 'johansen_critical.csv'), opts{:});
t.joh_p = unique(joh.p, 'stable')';
names = unique(joh.table, 'stable');
t.joh = struct();
for k = 1:numel(names)
    rows = joh.table == names(k);
    % rows = number of non-stationary directions g, columns = p-values
    t.joh.(names(k)) = reshape(joh.value(rows), [], numel(t.joh_p));
end

lil = readtable(fullfile(dir, 'lilliefors_critical.csv'), opts{:});
t.lillie_n = unique(lil.n, 'stable')';
t.lillie_p = unique(lil.p, 'stable')';
t.lillie = reshape(lil.value, numel(t.lillie_n), numel(t.lillie_p));

cache = t;
end
