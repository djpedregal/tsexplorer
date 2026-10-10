import numpy as np
from scipy import stats

import tsexplorer as tsx

from conftest import data, expect_equal, expect_ref, ref, values


def test_testhet_matches_the_reference_values():
    th = ref("testhet")
    airpas = data("airpas")
    cases = {"airpas": tsx.testhet(airpas), "airpas_cuts": tsx.testhet(airpas, [48, 96]),
             "airpas_matrix": tsx.testhet(airpas, [[1, 30], [50, 90], [100, 144]]),
             "scc": tsx.testhet(data("scc"))}
    for nm, r in cases.items():
        expect_ref(r.samples, th[nm]["timecuts"])
        # degrees of freedom n - 1 (column 6 of the reference)
        expect_ref(r.table[["f", "p_value"]], np.array(th[nm]["table"])[:, [3, 5]])


def _var_test_p(x, y):
    f = np.var(x, ddof=1) / np.var(y, ddof=1)
    p = stats.f.cdf(f, len(x) - 1, len(y) - 1)
    return 2 * min(p, 1 - p)


def test_testhet_time_cuts_and_agreement_with_the_f_test():
    airpas = data("airpas")
    a = values(airpas).ravel()
    r = tsx.testhet(airpas, [48, 96])
    assert r.samples.tolist() == [[1, 48], [49, 96], [97, 144]]
    expect_equal(r.table["p_value"][0], _var_test_p(a[:48], a[48:96]), tolerance=1e-10)
    # invalid cuts fall back to the default three subsamples
    assert tsx.testhet(airpas, 2).samples.shape[0] == 3
    # rows of a matrix starting before observation 5 are removed
    # (only after the first one)
    r = tsx.testhet(airpas, [[1, 40], [3, 60], [70, 144]])
    assert r.samples.tolist() == [[1, 40], [70, 144]]


def test_vboxcox_matches_the_reference_values():
    bc = ref("vboxcox")
    r = tsx.vboxcox(data("airpas"), group=12)
    expect_ref(r.lambdas, bc["airpas"]["lambdas"])
    expect_ref(r.grid.iloc[:, 1:7], np.hstack([bc["airpas"]["grid"], bc["airpas"]["grid_std"]]))
    r = tsx.vboxcox(data("lydia_pinkham"), group=6, axislambdas=np.arange(-1, 1.01, 0.25),
                    series=2)
    expect_ref(r.lambdas, bc["lydia"]["lambdas"])
    expect_ref(r.grid.iloc[:, 1:7], np.hstack([bc["lydia"]["grid"], bc["lydia"]["grid_std"]]))


def test_vboxcox_transforms_with_given_lambdas():
    airpas = data("airpas")
    r = tsx.vboxcox(airpas, lambdas=0)
    assert not r.estimated
    expect_equal(r.transformed.ravel(), np.log(values(airpas).ravel()))
    r = tsx.vboxcox(data("scc"), lambdas=[1, 0.5])
    assert list(r.lambdas.values()) == [1, 0.5, 0.5]
