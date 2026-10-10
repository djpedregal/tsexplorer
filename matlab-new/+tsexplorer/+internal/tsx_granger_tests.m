function tests = tsx_granger_tests(tests, m)
%TSX_GRANGER_TESTS Default and validation of the Granger tests ("a-b": b
%   does not cause a). Invalid tests are dropped; if none is valid, the
%   default (all the pairs) is returned. Row string vector.
letters = 'a':'z';
t1 = repmat(1:m, 1, m);
t2 = repelem(1:m, m);
keep = t1 ~= t2;
def = string(letters(t1(keep))') + "-" + string(letters(t2(keep))');
def = def';
if isempty(tests)
    tests = def;
    return
end
tests = string(tests);
if numel(tests) == 1
    tests = split(strtrim(tests))';
end
tests = lower(regexprep(tests, '\s', ''));
ok = false(size(tests));
for k = 1:numel(tests)
    ti = tests(k);
    if isempty(regexp(ti, '^[a-z]+-[a-z]+$', 'once'))
        continue
    end
    let = double(char(erase(ti, "-"))) - 96;
    ok(k) = all(let >= 1 & let <= m) && numel(unique(let)) == numel(let);
end
tests = tests(ok);
if isempty(tests)
    tests = def;
end
tests = tests(:)';
end
