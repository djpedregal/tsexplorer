# Documentation: every exported function has its help (docstring) with the
# sections of the R help pages (description, Parameters, Returns,
# References when the R page has them, See Also, Examples), documents all
# its arguments, and its examples run (as R CMD check runs the examples).

import inspect
import re

import numpy as np
import pandas as pd
import pytest
from matplotlib.figure import Figure

import tsexplorer as tsx
from tsexplorer import _windows

FUNCTIONS = [n for n in tsx.__all__ if inspect.isfunction(getattr(tsx, n))]
GUIS = ("tooltest", "toolforecast")
WITH_REFERENCES = ("adftest", "faccuracy", "fcompare", "gausstest", "johansentest", "nltests",
                   "varsbc", "vbds", "vboxcox", "vcumperiod", "vcusum", "vgranger", "vident",
                   "vident2", "vphillips", "vtsay")


def _sections(doc):
    return set(re.findall(r"^    (\w[\w ]*)\n    -{3,}$", doc, re.M))


def _documented_parameters(doc):
    m = re.search(r"^    Parameters\n    -+\n(.*?)(?=^    \w[\w ]*\n    -{3,}$|\Z)", doc,
                  re.M | re.S)
    if not m:
        return set()
    names = set()
    for line in m.group(1).splitlines():
        if re.match(r"^    [*\w]", line):
            for n in line.split(" : ")[0].split(","):
                names.add(n.strip().lstrip("*"))
    return names


def test_the_package_has_its_help():
    doc = tsx.__doc__
    for name in FUNCTIONS:
        assert name in doc, name
    assert "Graphical interfaces" in doc


@pytest.mark.parametrize("name", FUNCTIONS)
def test_every_function_has_its_help(name):
    fun = getattr(tsx, name)
    doc = inspect.getdoc(fun)
    assert doc and len(doc.splitlines()[0]) > 10, name
    doc = "    " + fun.__doc__.strip() if not fun.__doc__.startswith("\n") else fun.__doc__
    doc = inspect.cleandoc(fun.__doc__)
    doc = "\n".join("    " + s if s else s for s in doc.splitlines())
    sections = _sections(doc)
    if name == "mainloop":
        return
    for sec in ("Parameters", "Returns", "See Also", "Examples"):
        assert sec in sections, (name, sec)
    if name in WITH_REFERENCES:
        assert "References" in sections, name
    params = [p.name for p in inspect.signature(fun).parameters.values()]
    missing = set(params) - _documented_parameters(doc)
    assert not missing, (name, missing)


def _examples(fun):
    lines = []
    for s in inspect.cleandoc(fun.__doc__).splitlines():
        s = s.strip()
        if s.startswith(">>> "):
            lines.append(s[4:])
        elif s.startswith("... ") and lines:
            lines[-1] += "\n" + s[4:]
    return lines


def _tk_available():
    import os
    if os.environ.get("TSX_NO_TK"):   # no usable display (e.g. macOS CI runners)
        return False
    try:
        import tkinter as tk
        root = tk.Tk()
        root.destroy()
        return True
    except Exception:
        return False


@pytest.mark.parametrize("name", FUNCTIONS)
def test_the_examples_run(name):
    fun = getattr(tsx, name)
    code = _examples(fun)
    if name == "mainloop":
        assert code == []
        return
    assert code, name
    if name in GUIS and not _tk_available():
        pytest.skip("no display for Tk")
    ns = {"np": np, "pd": pd, "tsx": tsx}
    ns.update({n: getattr(tsx, n) for n in tsx.__all__})
    for g in GUIS:   # the interfaces return at once in the tests
        ns[g] = (lambda g: lambda *a, **k: getattr(tsx, g)(*a, wait=False, **k))(g)
    try:
        for stmt in code:
            try:
                value = eval(compile(stmt, name, "eval"), ns)
            except SyntaxError:
                exec(compile(stmt, name, "exec"), ns)
                continue
            if isinstance(value, tsx.TsxResult):
                assert len(value.text()) > 0
                if value.has_plot():
                    value.plot(fig=Figure())
    finally:
        for k in list(_windows._WINDOWS):
            _windows._WINDOWS[k].close()
