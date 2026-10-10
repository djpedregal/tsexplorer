function tests = test_examples
% The examples of the help of every function of the package run without
% errors (as the examples in the check of the R package). The examples of
% the graphical interfaces are not run.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.visible = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
end

function teardownOnce(tc)
close all force
set(groot, 'DefaultFigureVisible', tc.TestData.visible);
end

function names = documented_functions()
% exported functions: the files of the folder but Contents.m and run_tests.m,
% and the functions of the package tsexplorer
here = fileparts(fileparts(mfilename('fullpath')));
f = dir(fullfile(here, '*.m'));
names = string(erase({f.name}, ".m"));
names = setdiff(names, ["Contents", "run_tests"]);
f = dir(fullfile(here, '+tsexplorer', '*.m'));
% (tsexplorer.adftest is documented in adftest)
names = [names, "tsexplorer." + setdiff(string(erase({f.name}, ".m")), ["Contents", "adftest"])];
end

function code = examples_of(name)
% code of the section Examples of the help of NAME
h = splitlines(string(help(name)));
i = find(strtrim(h) == "Examples:", 1);
code = strings(0, 1);
if isempty(i)
    return
end
for k = (i + 1):numel(h)
    if startsWith(strtrim(h(k)), "See also")
        break
    end
    code(end + 1, 1) = strtrim(h(k)); %#ok<AGROW>
end
end

function test_every_function_has_the_sections_of_its_help(tc)
for name = documented_functions()
    h = string(help(name));
    for sec = ["Arguments:", "Value:", "Examples:", "See also"]
        tc.verifyTrue(contains(h, sec), name + ": no section " + sec);
    end
end
end

function test_contents_lists_every_function(tc)
here = fileparts(fileparts(mfilename('fullpath')));
c = string(fileread(fullfile(here, 'Contents.m')));
for name = documented_functions()
    tc.verifyTrue(contains(c, " " + name + " "), name + " is not in Contents.m");
end
end

function test_examples_run(tc)
for name = setdiff(documented_functions(), ["tooltest", "toolforecast"])
    code = examples_of(name);
    tc.verifyNotEmpty(code, name + ": no examples");
    try
        run_code(strjoin(code, newline));
    catch err
        tc.verifyFail(name + ": " + err.message);
    end
    close all force
end
end

function run_code(code__)
% evaluate the examples in a workspace of their own
evalc(code__);
end
