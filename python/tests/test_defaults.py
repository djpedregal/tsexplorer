import math

import pytest

import tsexplorer as tsx

from conftest import data


def test_tooltest_defaults_gives_the_documented_default_options():
    d = tsx.tooltest_defaults(data("airpas"))
    assert d["vident"]["ncoef"] == 38
    assert d["adftest"]["lags"] == list(range(1, 13))
    assert d["vphillips"]["ncovs"] == math.floor(4 * (144 / 100) ** 0.25)
    assert d["testhet"]["timecuts"] == [48, 98]
    assert d["vscatter"]["bins"] == 12
    assert d["nltests"]["ncoef"] == 12
    d2 = tsx.tooltest_defaults(data("scc"))
    assert d2["adftest"]["lags"] == [7]
    assert d2["vgranger"]["tests"] == ["b-a", "c-a", "a-b", "c-b", "a-c", "b-c"]
    assert d2["vident"]["ncoef"] == min(38, math.ceil(62 / 4 / 3 * 2))
    assert "s" in d.links


def test_tooltest_defaults_applies_overrides_and_linked_options():
    airpas = data("airpas")
    d = tsx.tooltest_defaults(airpas, vident={"ncoef": 50, "s": 4, "npar": 1},
                              varspectrum=[20])
    assert d["vident"]["ncoef"] == 50
    assert d["varspectrum"]["order"] == 20
    # linked seasonal period and lags
    assert d["plotband"]["s"] == 4
    assert d["stdmean"]["s"] == 4
    assert d["vboxcox"]["group"] == 4
    assert d["varsbc"]["ncoef"] == 50
    d = tsx.tooltest_defaults(airpas, vphillips={"lags": [1, 2, 3]})
    assert d["adftest"]["lags"] == [1, 2, 3]
    assert d["johansentest"]["lags"] == [1, 2, 3]
    # a single value is the first option of the tool
    assert tsx.tooltest_defaults(airpas, vboxplot=4)["vtboxplot"]["s"] == 4
    with pytest.raises(ValueError, match="Unknown tool"):
        tsx.tooltest_defaults(airpas, foo=[1])
    with pytest.raises(ValueError, match="Unknown option"):
        tsx.tooltest_defaults(airpas, vident={"zz": 1})


def test_every_tool_runs_with_its_default_options():
    # the options of tooltest_defaults() are valid arguments of the tools
    for nm in ("airpas", "scc"):
        y = data(nm)
        d = tsx.tooltest_defaults(y)
        multi = tsx.as_tsx_matrix(y)[0].shape[1] > 1
        for tool, opts in d.items():
            if tool in ("vscatter", "vident2", "vgranger") and not multi:
                continue
            fun = getattr(tsx, tool)
            r = fun(y, **opts)
            assert r["class"][0] == "tsx_" + tool
