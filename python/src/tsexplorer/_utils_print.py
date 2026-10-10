# Text output helpers used by the text methods (print() methods of R). The
# text methods return the lines of text (without the final newlines).

import math

import numpy as np
import pandas as pd


def tsx_fmt_f(v, digits):
    """formatC(v, format = "f", digits = digits) of R, with "NA", "Inf" and
    "-Inf"."""
    if v is None or (isinstance(v, float) and math.isnan(v)) or pd.isna(v):
        return "NA"
    v = float(v)
    if math.isinf(v):
        return "Inf" if v > 0 else "-Inf"
    return "%.*f" % (int(digits), v)


def tsx_sprintf_f(fmt, *args):
    """sprintf() of R for numeric formats: missing values are written as
    "NA" (the format of each NA argument is replaced by %s)."""
    parts = fmt.split("%")
    out = [parts[0]]
    k = 0
    i = 1
    while i < len(parts):
        p = parts[i]
        if p == "":
            out.append("%")
            out.append(parts[i + 1] if i + 1 < len(parts) else "")
            i += 2
            continue
        j = 0
        while j < len(p) and p[j] not in "dfgsei":
            j += 1
        spec, rest = p[:j + 1], p[j + 1:]
        v = args[k]
        k += 1
        if spec[-1] != "s" and (v is None or (isinstance(v, (float, np.floating)) and np.isnan(v))):
            out.append("NA")
        elif spec[-1] == "d":
            out.append(("%" + spec) % int(v))
        else:
            out.append(("%" + spec) % v)
        out.append(rest)
        i += 1
    return "".join(out)


def tsx_format_g(x):
    """format() of R for one number (7 significant digits)."""
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "NA"
    x = float(x)
    if x == int(x) and abs(x) < 1e15:
        return "%d" % int(x)
    s = "%.7g" % x
    if "e" in s:
        mant, exp = s.split("e")
        s = mant + "e" + exp[0] + exp[1:].rjust(2, "0")
    return s


def tsx_num2str(x):
    """as.character() / paste() of R for one number (15 significant
    digits)."""
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "NA"
    x = float(x)
    if x == int(x) and abs(x) < 1e15:
        return "%d" % int(x)
    return "%.15g" % x


def _columns(x):
    if isinstance(x, pd.DataFrame):
        return [x.iloc[:, j].to_numpy() for j in range(x.shape[1])], [str(c) for c in x.columns]
    if isinstance(x, np.ndarray) and x.ndim == 2:
        return [x[:, j] for j in range(x.shape[1])], ["V%d" % (j + 1) for j in range(x.shape[1])]
    cols = [np.asarray(c) if not isinstance(c, (list, tuple)) else np.asarray(c, dtype=object)
            for c in x]
    return cols, ["V%d" % (j + 1) for j in range(len(cols))]


def tsx_format_table(x, digits=4, row_names=None, col_names=None):
    """Format a table (DataFrame, matrix or list of columns) as lines of
    text. ``digits``: decimals of each numeric column (recycled); missing
    values printed as "NA". Text columns are printed as they are. Columns
    are right aligned and separated by two blanks; the row names are left
    aligned."""
    cols, names = _columns(x)
    if col_names is None:
        col_names = names
    digits = list(np.atleast_1d(digits))
    digits = [digits[j % len(digits)] for j in range(len(cols))]
    text = []
    for j, v in enumerate(cols):
        if v.dtype.kind in "biuf":
            text.append([tsx_fmt_f(e, digits[j]) for e in v])
        else:
            text.append(["NA" if e is None else str(e) for e in v])
    widths = [max([len(col_names[j])] + [len(s) for s in text[j]]) for j in range(len(cols))]
    nrow = len(cols[0]) if cols else 0
    lines = ["  ".join(col_names[j].rjust(widths[j]) for j in range(len(cols)))]
    for i in range(nrow):
        lines.append("  ".join(text[j][i].rjust(widths[j]) for j in range(len(cols))))
    if row_names is not None:
        row_names = [str(r) for r in row_names]
        rw = max(len(r) for r in row_names)
        rn = [""] + list(row_names)
        lines = [rn[i].ljust(rw) + "  " + lines[i] for i in range(len(lines))]
    return lines


def tsx_cat_block(title=None, notes=None, table=None):
    """Block of text lines: title lines, notes and a ruled table."""
    def aslist(v):
        if v is None:
            return []
        return [v] if isinstance(v, str) else [s for s in v if s is not None]

    title, notes, table = aslist(title), aslist(notes), aslist(table)
    width = max([len(s) for s in title + notes + table + [""]] + [40])
    rule = "-" * width
    out = [rule]
    if title:
        out += title + [rule]
    if notes:
        out += notes + [rule]
    if table:
        out += [table[0], rule] + table[1:] + [rule]
    return out


def tsx_series_text(series):
    """Names of the series of a result as a list."""
    if series is None:
        return []
    return [series] if isinstance(series, str) else list(series)
