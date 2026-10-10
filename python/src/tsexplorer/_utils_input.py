# Input handling shared by every function of the package.
# All the computational code only ever sees a numeric T x m matrix (numpy
# array of floats) with a list of names (time in rows, series in columns).

import re

import numpy as np
import pandas as pd


def as_tsx_matrix(y, names=None, trim=True):
    """Convert input data to the matrix format used by tsexplorer.

    Every function of the package accepts data without dates (number, list,
    numpy array or ``pandas`` object without dates) or with dates (``pandas``
    ``Series``/``DataFrame`` indexed by a ``PeriodIndex`` or a
    ``DatetimeIndex``, or a ``DataFrame`` with one date column) and converts
    it with this function into a numeric ``T x m`` matrix (rows are time,
    columns are series) with the names of the series.

    The dates, when available, are returned as a ``pandas.DatetimeIndex``
    (one per row) and are used in the time axes of the plots and in the
    tables of the forecasting tools. A ``PeriodIndex`` (the equivalent of a
    ``ts`` object of R) gives the first day of each period. Dates must be
    increasing and without repetitions.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Numeric data (numeric columns and, optionally, one date column in a
        ``DataFrame``).
    names : str or list of str, optional
        Names of the series. If shorter than the number of series, the
        remaining ones take the default names ``"#1"``, ``"#2"``, ... A single
        string with blank-separated names is also accepted.
    trim : bool
        If ``True`` (default), rows at the beginning and at the end of the
        sample where all the series are missing are removed.

    Returns
    -------
    y : numpy.ndarray
        Matrix ``T x m`` of floats (missing values are ``nan``).
    names : list of str
        Names of the series.
    dates : pandas.DatetimeIndex or None
        Dates of the rows for dated inputs, ``None`` otherwise.

    See Also
    --------
    load_data

    Examples
    --------
    >>> y, names, dates = as_tsx_matrix(load_data("airpas"))
    >>> as_tsx_matrix([[1, 2], [3, 4]], names="a b")[1]
    ['a', 'b']
    """
    values, cn, dates, _ = tsx_input_parts(y)
    y = values
    if y is None or np.size(y) == 0:
        raise ValueError("'y' is empty.")
    y = np.asarray(y)
    if y.dtype.kind not in "biuf":
        raise ValueError("'y' must be numeric (number, list, array, Series or DataFrame).")
    y = np.array(y, dtype=float)
    if y.ndim == 0:
        y = y.reshape(1, 1)
    elif y.ndim == 1:
        y = y.reshape(-1, 1)
    elif y.ndim != 2:
        raise ValueError("'y' must have at most two dimensions.")
    m = y.shape[1]
    names = tsx_names(m, cn if names is None else names)
    if dates is not None and len(dates) != y.shape[0]:
        raise ValueError("The number of dates and of observations of 'y' differ.")
    if trim:
        y, idx = tsx_remove_nan(y)
        if dates is not None and idx is not None:
            dates = dates[idx]
    if y.shape[0] == 0:
        raise ValueError("'y' contains only missing values.")
    return y, names, dates


def tsx_input_parts(y):
    """Values, column names, dates and type of an input object.

    The type is ``"period"`` (``PeriodIndex``, the ``ts`` objects of R),
    ``"datetime"`` (``DatetimeIndex``, the ``zoo``/``xts`` objects of R),
    ``"data.frame"`` (``DataFrame`` with one date column) or ``"undated"``;
    the dates are ``None`` for ``"undated"``.
    """
    if isinstance(y, (pd.Series, pd.DataFrame)):
        frame = y.to_frame() if isinstance(y, pd.Series) else y
        index = y.index
        if isinstance(index, pd.PeriodIndex):
            values, cn = _frame_values(frame, isinstance(y, pd.Series))
            return values, cn, tsx_check_dates(index.to_timestamp(how="start")), "period"
        if isinstance(index, pd.DatetimeIndex):
            values, cn = _frame_values(frame, isinstance(y, pd.Series))
            return values, cn, tsx_check_dates(index), "datetime"
        if isinstance(y, pd.DataFrame):
            isdate = [_is_date_column(y.iloc[:, k]) for k in range(y.shape[1])]
            if sum(isdate) > 1:
                raise ValueError("'y' has more than one date column.")
            if sum(isdate) == 1:
                k = isdate.index(True)
                d = y.iloc[:, k]
                if isinstance(d.dtype, pd.PeriodDtype):
                    d = d.dt.to_timestamp(how="start")
                rest = y.drop(columns=y.columns[k])
                values, cn = _frame_values(rest, False)
                return values, cn, tsx_check_dates(pd.DatetimeIndex(d)), "data.frame"
        values, cn = _frame_values(frame, isinstance(y, pd.Series))
        return values, cn, None, "undated"
    return y, None, None, "undated"


def _is_date_column(v):
    return pd.api.types.is_datetime64_any_dtype(v.dtype) or isinstance(v.dtype, pd.PeriodDtype)


# Numeric values and column names of a DataFrame (the name of a Series, if
# any; default column labels 0, 1, ... are not names).
def _frame_values(frame, is_series):
    for k in range(frame.shape[1]):
        dt = frame.iloc[:, k].dtype
        if not (pd.api.types.is_numeric_dtype(dt) or pd.api.types.is_bool_dtype(dt)):
            raise ValueError("All the columns of 'y' must be numeric (except one date column).")
    values = frame.to_numpy(dtype=float, na_value=np.nan)
    if is_series:
        name = frame.columns[0]
        cn = None if name is None or (isinstance(name, int) and name == 0) else [str(name)]
    elif isinstance(frame.columns, pd.RangeIndex):
        cn = None
    else:
        cn = [str(c) for c in frame.columns]
    return values, cn


def tsx_check_dates(d):
    """Normalise and check a vector of dates (``DatetimeIndex``): increasing
    and without repetitions or missing values."""
    d = pd.DatetimeIndex(d)
    if d.hasnans or not (d.is_monotonic_increasing and d.is_unique):
        raise ValueError("The dates must be increasing, without repetitions or missing values.")
    return d


def tsx_date_kind(d):
    """Kind of a vector of dates: ``"Date"`` (all the times are midnight,
    without time zone), ``"POSIXct"`` (date-time without time zone) or
    ``"POSIXct <tz>"`` (with time zone)."""
    if d.tz is not None:
        return "POSIXct " + str(d.tz)
    if len(d) == 0 or bool((d == d.normalize()).all()):
        return "Date"
    return "POSIXct"


def tsx_format_dates(d):
    """Dates as text for the tables: ``"%Y-%m"`` when all the dates are first
    days of months, ``"%Y-%m-%d"`` for other dates and ``"%Y-%m-%d
    %H:%M:%S"`` for date-times."""
    if d is None:
        return None
    d = pd.DatetimeIndex(d)
    kind = tsx_date_kind(d)
    if kind == "Date":
        fmt = "%Y-%m" if bool((d.day == 1).all()) else "%Y-%m-%d"
    else:
        fmt = "%Y-%m-%d %H:%M:%S"
    return ["NA" if pd.isna(v) else v.strftime(fmt) for v in d]


def tsx_names(m, names=None):
    """Default and user supplied names of the series (``"#1"``, ``"#2"``,
    ...)."""
    out = ["#%d" % (k + 1) for k in range(m)]
    if names is None:
        return out
    if isinstance(names, str):
        names = [names]
    names = [None if v is None else str(v) for v in names]
    if len(names) == 1 and m > 1 and names[0] is not None:
        names = re.split(r"\s+", names[0].strip())
    for k in range(min(len(names), m)):
        if names[k] is not None and names[k] != "" and names[k] != "nan":
            out[k] = names[k]
    return out


def tsx_remove_nan(y):
    """Remove rows with all the series missing at the beginning and end of
    the sample. Returns the trimmed matrix and the indices (0-based) of the
    rows retained, ``None`` if no row is removed."""
    allna = np.all(np.isnan(y), axis=1)
    if not allna.any():
        return y, None
    ok = np.nonzero(~allna)[0]
    if len(ok) == 0:
        return y[:0, :], np.arange(0)
    idx = np.arange(ok[0], ok[-1] + 1)
    return y[idx, :], idx


def tsx_series_index(series, names, allow_all=False):
    """Resolve a series selector (number from 1 or name, or a list of them)
    into a list of column numbers (from 1, as the default names ``#1``,
    ``#2``, ...). ``allow_all`` accepts ``"all"`` and returns all the
    columns."""
    m = len(names)
    if series is None:
        series = 1
    if isinstance(series, str) or (
        isinstance(series, (list, tuple, np.ndarray)) and len(series) > 0
        and all(isinstance(s, str) for s in series)
    ):
        sel = [series] if isinstance(series, str) else list(series)
        if allow_all and len(sel) == 1 and sel[0].lower() == "all":
            return list(range(1, m + 1))
        missing = [s for s in sel if s not in names]
        if missing:
            raise ValueError("Series not found: " + ", ".join(missing))
        return [names.index(s) + 1 for s in sel]
    sel = np.atleast_1d(np.asarray(series, dtype=float))
    if np.any(np.isnan(sel)) or np.any(sel < 1) or np.any(sel >= m + 1):
        raise ValueError("'series' must be between 1 and %d." % m)
    return [int(s) for s in sel]


def tsx_check_int(x, name, min=1):
    """Check a single integer option (>= min) and round it."""
    if isinstance(x, (list, tuple, np.ndarray)):
        x = np.asarray(x).ravel()
        x = x[0] if x.size == 1 else None
    if isinstance(x, np.generic):
        x = x.item()
    if (x is None or isinstance(x, bool) or not isinstance(x, (int, float))
            or np.isnan(x) or x < min):
        raise ValueError("'%s' must be a single number >= %s." % (name, min))
    return int(round(x))


def tsx_is_all(series):
    """``True`` when a series selector is the string ``"all"``."""
    if isinstance(series, (list, tuple)) and len(series) > 0:
        series = series[0]
    return isinstance(series, str) and series.lower() == "all"
