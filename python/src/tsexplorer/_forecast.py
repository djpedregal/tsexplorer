# Forecast evaluation tools: faccuracy(), fcompare() and fplot().
#
# Layout of the inputs:
#   y      T x m matrix of actual values.
#   py     forecasts, n * m columns: forecast f of series s is column
#          (f - 1) * m + s (numbers from 1).
#   stdpy  standard deviations of the forecasts, n * m columns with the
#          layout of py.
# The bands are py -/+ z * stdpy, with z the (1 + level) / 2 quantile of the
# standard normal distribution; internally they are kept in a matrix with
# 2 * n * m columns: lower band of forecast f of series s in column
# (f - 1) * 2 * m + s and the upper band in (f - 1) * 2 * m + m + s.
# y and py must be of the same type: both without dates (aligned by
# position), both with a PeriodIndex (the ts objects of R, aligned on their
# common time grid) or both with a DatetimeIndex or both DataFrames with a
# date column (aligned by their dates).

import math

import numpy as np
import pandas as pd
from scipy import stats

from ._result import TsxNoOverlapError, plot_method, text_method, tsx_result
from ._utils_input import (as_tsx_matrix, tsx_check_int, tsx_date_kind, tsx_format_dates,
                           tsx_input_parts, tsx_series_index)
from ._utils_math import nanmean, nanvar, tsx_nancumsum, tsx_signrank
from ._utils_plot import col, tsx_time_coords, tsx_xlim, tsx_ylim
from ._utils_print import tsx_cat_block, tsx_format_g, tsx_format_table


def tsx_forecast_align(y, py, stdpy=None, origin=0, names=None, level=0.95):
    """Alignment of actual values, forecasts and standard deviations.
    Returns a dict with y, py, stdpy (matrices with the same number of rows),
    bands (None without stdpy), origin, nf (number of forecasts), names and
    dates (date of each row, or None when the inputs have no dates)."""
    tsx_check_level(level)
    a = tsx_forecast_align_inputs(y, py, stdpy, origin, names)
    a["bands"] = tsx_forecast_bands(a["py"], a["stdpy"], a["y"].shape[1], level)
    return a


def tsx_forecast_bands(py, stdpy, m, level):
    """Bands py -/+ z * stdpy, z = qnorm((1 + level) / 2), in the internal
    layout (2 * n * m columns, see the top of this file)."""
    if stdpy is None:
        return None
    z = stats.norm.ppf((1 + level) / 2)
    bands = np.full((py.shape[0], 2 * py.shape[1]), np.nan)
    for f in range(py.shape[1] // m):
        pc = f * m + np.arange(m)
        lc = f * 2 * m + np.arange(m)
        bands[:, lc] = py[:, pc] - z * stdpy[:, pc]
        bands[:, lc + m] = py[:, pc] + z * stdpy[:, pc]
    return bands


def tsx_forecast_align_inputs(y, py, stdpy, origin, names):
    type_y = tsx_input_parts(y)[3]
    type_p = tsx_input_parts(py)[3]
    if type_y != type_p:
        raise ValueError("'y' and 'py' must be of the same type (%s and %s given)."
                         % (tsx_type_label(type_y), tsx_type_label(type_p)))
    if stdpy is not None:
        type_s = tsx_input_parts(stdpy)[3]
        if type_s not in (type_p, "undated"):
            raise ValueError("'stdpy' must be of the same type as 'py' or have no dates "
                             "(%s given)." % tsx_type_label(type_s))
    if type_y == "undated":
        return tsx_forecast_align_rows(y, py, stdpy, origin, names)
    if type_y == "period":
        return tsx_forecast_align_period(y, py, stdpy, origin, names)
    return tsx_forecast_align_index(y, py, stdpy, origin, names)


def tsx_type_label(type_):
    """Description of an input type for the error messages."""
    return {"undated": "data without dates",
            "period": "a pandas object with a PeriodIndex",
            "datetime": "a pandas object with a DatetimeIndex",
            "data.frame": "a DataFrame with a date column"}.get(type_, type_)


def tsx_values_matrix(x):
    """Numeric matrix of the values of an input object (without its
    dates)."""
    try:
        v = tsx_input_parts(x)[0]
        v = np.array(v, dtype=float)
    except ValueError:
        raise ValueError("All the columns of the forecasts and their standard deviations "
                         "must be numeric.") from None
    if v.ndim == 0:
        v = v.reshape(1, 1)
    elif v.ndim == 1:
        v = v.reshape(-1, 1)
    return v


def tsx_sd_cols(sm, mh):
    """Standard deviations of the forecasts: mh columns, the layout of py
    (missing ones filled with nan)."""
    if sm.shape[1] > mh:
        raise ValueError("'stdpy' must have at most as many columns as 'py' (the standard "
                         "deviations of the forecasts), not %d." % sm.shape[1])
    if np.any(sm[~np.isnan(sm)] < 0):
        raise ValueError("'stdpy' must contain standard deviations (non negative values).")
    if sm.shape[1] < mh:
        sm = np.hstack([sm, np.full((sm.shape[0], mh - sm.shape[1]), np.nan)])
    return sm


def tsx_check_py_cols(mh, m):
    if mh % m != 0:
        raise ValueError("The number of columns of 'py' must be a multiple of the number of "
                         "series.")


def tsx_forecast_align_rows(y, py, stdpy, origin, names):
    """Alignment by position of data without dates: series of different
    lengths are aligned at the end (padding with missing values at the
    beginning); when y is longer than py the forecast origin is
    T - nrow(py)."""
    y, names, _ = as_tsx_matrix(y, names, trim=False)
    py = tsx_values_matrix(py)
    n, m = y.shape
    nh, mh = py.shape
    tsx_check_py_cols(mh, m)
    if stdpy is not None:
        stdpy = tsx_sd_cols(tsx_values_matrix(stdpy), mh)
    if origin is None:
        origin = 0
    if nh > n:
        y = np.vstack([y, np.full((nh - n, m), np.nan)])
    n = y.shape[0]
    pp = max(0 if stdpy is None else stdpy.shape[0], nh, n)

    def pad(x):
        if x is None or x.shape[0] == pp:
            return x
        return np.vstack([np.full((pp - x.shape[0], x.shape[1]), np.nan), x])

    if n > nh:
        origin = n - nh
    return {"y": pad(y), "py": pad(py), "stdpy": pad(stdpy), "origin": int(origin),
            "nf": mh // m, "names": names, "dates": None}


def tsx_forecast_align_period(y, py, stdpy, origin, names):
    """Alignment of inputs with a PeriodIndex (the ts objects of R). The
    common grid goes from the earliest start to the latest end of y, py and
    stdpy (all with the same frequency); every input is placed at the rows
    of its dates, with missing values elsewhere. stdpy may have a
    PeriodIndex or be a matrix with the rows of py. When 'origin' is 0 it is
    set to the number of periods before the start of py."""
    freq = y.index.freqstr
    if py.index.freqstr != freq:
        raise ValueError("'y' and 'py' must have the same frequency.")
    std_per = stdpy is not None and isinstance(getattr(stdpy, "index", None), pd.PeriodIndex)
    if std_per and stdpy.index.freqstr != freq:
        raise ValueError("'y' and 'stdpy' must have the same frequency.")
    idxs = [y.index, py.index] + ([stdpy.index] if std_per else [])
    t0 = min(ix[0].ordinal for ix in idxs)
    t1 = max(ix[-1].ordinal for ix in idxs)
    nrows = t1 - t0 + 1

    def place(x, start):
        out = np.full((nrows, x.shape[1]), np.nan)
        out[start:start + x.shape[0], :] = x
        return out

    yy, names, _ = as_tsx_matrix(y, names, trim=False)
    pm = tsx_values_matrix(py)
    m = yy.shape[1]
    mh = pm.shape[1]
    tsx_check_py_cols(mh, m)
    py_start = py.index[0].ordinal - t0
    yy = place(yy, y.index[0].ordinal - t0)
    pm = place(pm, py_start)
    if stdpy is not None:
        sm = tsx_values_matrix(stdpy)
        if std_per:
            s_start = stdpy.index[0].ordinal - t0
        elif sm.shape[0] == len(py):
            s_start = py_start
        else:
            raise ValueError("'stdpy' must have a PeriodIndex or the same number of rows as "
                             "'py'.")
        stdpy = place(tsx_sd_cols(sm, mh), s_start)
    if origin is None or origin == 0:
        origin = py_start
    grid = pd.period_range(start=pd.Period(ordinal=t0, freq=freq), periods=nrows, freq=freq)
    return {"y": yy, "py": pm, "stdpy": stdpy, "origin": int(origin), "nf": mh // m,
            "names": names, "dates": grid.to_timestamp(how="start")}


def tsx_forecast_align_index(y, py, stdpy, origin, names):
    """Alignment by dates of inputs with a DatetimeIndex or a date column:
    the rows are the union of the dates of y, py and stdpy; every input is
    placed at the rows of its dates, with missing values elsewhere. stdpy
    may be dated or a matrix with the rows of py. When 'origin' is 0 it is
    set to the number of dates before the first date of py."""
    yy, names, dy = as_tsx_matrix(y, names, trim=False)
    dp = tsx_input_parts(py)[2]
    pm = tsx_values_matrix(py)
    if (dy.tz is None) != (dp.tz is None):
        raise ValueError("The dates of 'y' and 'py' are of different kinds (%s and %s)."
                         % (tsx_date_kind(dy), tsx_date_kind(dp)))
    if len(dp) != pm.shape[0]:
        raise ValueError("The number of dates and of rows of 'py' differ.")
    m = yy.shape[1]
    mh = pm.shape[1]
    tsx_check_py_cols(mh, m)
    ds = None
    if stdpy is not None:
        sm = tsx_values_matrix(stdpy)
        ds = tsx_input_parts(stdpy)[2]
        if ds is None:
            if sm.shape[0] != pm.shape[0]:
                raise ValueError("'stdpy' must have dates or the same number of rows as 'py'.")
            ds = dp
        elif (ds.tz is None) != (dp.tz is None):
            raise ValueError("The dates of 'py' and 'stdpy' are of different kinds.")
    alld = dy.union(dp)
    if ds is not None:
        alld = alld.union(ds)
    alld = alld.sort_values()

    def place(x, d):
        out = np.full((len(alld), x.shape[1]), np.nan)
        out[alld.get_indexer(d), :] = x
        return out

    yy = place(yy, dy)
    pm2 = place(pm, dp)
    if stdpy is not None:
        stdpy = place(tsx_sd_cols(sm, mh), ds)
    if origin is None or origin == 0:
        origin = int(np.sum(alld < dp[0]))
    return {"y": yy, "py": pm2, "stdpy": stdpy, "origin": int(origin), "nf": mh // m,
            "names": names, "dates": alld}


def tsx_forecast_cols(series, m, nf):
    """Columns (0-based) of the forecasts and bands of one series (number
    from 1)."""
    f = np.arange(nf)
    return {"py": f * m + series - 1,
            "lower": f * 2 * m + series - 1,
            "upper": f * 2 * m + m + series - 1}


def tsx_check_overlap(actual, fc):
    """Error (TsxNoOverlapError) when no period after the origin has both an
    actual value and a forecast of the series (actual values and forecasts
    do not overlap), so that the GUI can show the plot without tables."""
    both = ~np.isnan(actual) & np.any(~np.isnan(np.atleast_2d(fc.T).T), axis=1)
    if not both.any():
        raise TsxNoOverlapError("The actual values and the forecasts do not overlap: no "
                                "accuracy measures can be computed.")


def tsx_no_overlap():
    raise TsxNoOverlapError("The actual values and the forecasts do not overlap: no accuracy "
                            "measures can be computed.")


def tsx_check_level(level):
    """Check the confidence level of the prediction intervals."""
    if (isinstance(level, bool) or not isinstance(level, (int, float, np.number))
            or np.isnan(level) or level <= 0 or level >= 1):
        raise ValueError("'level' must be a number between 0 and 1.")
    return level


def tsx_period_text(dates):
    """Forecasting period of the tables ("Forecasting period: first to
    last")."""
    if dates is None or len(dates) == 0:
        return None
    d = tsx_format_dates(dates)
    return "Forecasting period: %s to %s" % (d[0], d[-1])


def _mean_ok(x):
    return nanmean(x) if np.any(~np.isnan(x)) else np.nan


def _cummean_ok(x):
    k = np.cumsum(~np.isnan(x))
    with np.errstate(all="ignore"):
        out = tsx_nancumsum(x) / k
    out[k == 0] = np.nan
    return out


def faccuracy(y, py, stdpy=None, origin=0, series=1, level=0.95, names=None):
    """Forecast accuracy measures.

    Error measures of one or several forecasts of one series over the
    forecasting period (observations after ``origin``), and measures of the
    uncertainty of their prediction intervals when ``stdpy`` is given.

    Point forecast measures, with :math:`e_t = F_t - y_t`:

    * Bias and MAE: mean error and mean absolute error.
    * Bias+MAE: :math:`|Bias| + MAE`.
    * RMSE: root mean squared error.
    * MASE: MAE relative to the in-sample MAE of the one step naive forecast
      (only when ``origin > 0``).

    Interval measures (only with ``stdpy``), with :math:`\\alpha = 1 -`
    ``level`` and the bounds of the Gaussian prediction intervals :math:`l_t
    = F_t - z \\sigma_t` and :math:`u_t = F_t + z \\sigma_t`, being
    :math:`\\sigma_t` the standard deviation of the forecast (``stdpy``) and
    :math:`z` the :math:`1 - \\alpha / 2` quantile of the standard normal
    distribution (1.96 for ``level = 0.95``):

    * Coverage: proportion of actual values inside :math:`[l_t, u_t]` (to be
      compared with ``level``).
    * Range: mean width :math:`u_t - l_t`.
    * MIS (mean interval score): mean of :math:`(u_t - l_t) +
      \\frac{2}{\\alpha} (l_t - y_t) 1(y_t < l_t) + \\frac{2}{\\alpha} (y_t
      - u_t) 1(y_t > u_t)`.
    * Pinball loss of the lower bound (quantile :math:`\\tau = \\alpha / 2`)
      and of the upper bound (:math:`\\tau = 1 - \\alpha / 2`): mean of
      :math:`\\tau (y_t - q_t)` if :math:`y_t \\ge q_t` and :math:`(1 -
      \\tau) (q_t - y_t)` otherwise.

    If no period after ``origin`` has both an actual value and a forecast
    (the forecasts do not overlap the actual values), an error
    :class:`TsxNoOverlapError` is raised. The same applies to
    :func:`fcompare`; :func:`fplot` returns these data without problems.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Actual values (see :func:`as_tsx_matrix`); it may include the
        in-sample period.
    py : array_like, pandas.Series or pandas.DataFrame
        Forecasts: a matrix with ``n * m`` columns, being ``m`` the number of
        series in ``y`` and ``n`` the number of forecasts; forecast ``f`` of
        series ``s`` is in column ``(f - 1) * m + s`` (numbers from 1). ``y``
        and ``py`` must be of the same type (an error is raised otherwise):
        both without dates (aligned at the end), both with a
        ``PeriodIndex`` of the same frequency (aligned on their common time
        grid), both with a ``DatetimeIndex`` or both ``DataFrame`` objects
        with a date column (aligned by their dates).
    stdpy : array_like, pandas.Series or pandas.DataFrame, optional
        Standard deviations of the forecasts, with the layout of ``py``
        (missing columns at the end are taken as not available). The
        prediction intervals are ``py -/+ z * stdpy``, with ``z =
        norm.ppf((1 + level) / 2)``. With dated inputs it may be of the same
        type as ``py`` or have no dates and the rows of ``py``.
    origin : int
        Forecast origin: number of in-sample observations. If ``y`` is
        longer than ``py``, it is set to ``len(y) - len(py)``. With dated
        inputs and ``origin = 0``, it is the number of periods before the
        first date of ``py`` (counted from the earliest date of ``y`` and
        ``py``).
    series : int or str
        Series to evaluate (number from 1 or name).
    level : float
        Confidence level of the prediction intervals computed from ``stdpy``
        (default 0.95); the significance level is :math:`\\alpha = 1 -`
        ``level``.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_faccuracy`` with fields ``call``, ``series``,
        ``table`` (DataFrame, one row per forecast, with columns
        ``forecast``, ``n``, ``bias``, ``mae``, ``bias_mae``, ``rmse``,
        ``mase``, ``coverage``, ``range``, ``mis``, ``pinball_lower`` and
        ``pinball_upper``; the interval measures are ``nan`` without
        ``stdpy``), ``by_horizon`` (DataFrame with the same measures
        accumulated up to each period of the forecasting sample, with
        columns ``forecast``, ``t``, ``date`` (only for dated inputs),
        ``actual``, ``fcst``, ``e`` and the measures) and ``dates`` (dates of
        the forecasting sample for dated inputs, otherwise ``None``).

    See Also
    --------
    TsxResult.text, fcompare, fplot, toolforecast

    References
    ----------
    Hyndman, R.J. and Koehler, A.B. (2006). Another look at measures of
    forecast accuracy. *International Journal of Forecasting*, 22, 679-688.

    Gneiting, T. and Raftery, A.E. (2007). Strictly proper scoring rules,
    prediction, and estimation. *Journal of the American Statistical
    Association*, 102, 359-378.

    Svetunkov, I. (2023). *Forecasting and Analytics with the Augmented
    Dynamic Adaptive Model (ADAM)*. Chapman and Hall/CRC.
    https://openforecast.org/adam/

    Examples
    --------
    >>> # data without dates (forecasts aligned with the end of y)
    >>> y = np.log(load_data("airpas").to_numpy())
    >>> f1 = y[120:132]                 # naive seasonal forecast
    >>> f2 = np.repeat(y[131], 12)      # naive forecast
    >>> faccuracy(y, np.column_stack([f1, f2]))
    >>> # with 95% intervals of the first forecast (standard deviation 0.05)
    >>> faccuracy(y, f1, np.repeat(0.05, 12))
    >>> # data with dates (both of the same type), aligned by their dates
    >>> d = pd.date_range("1949-01-01", periods=144, freq="MS")
    >>> yd = pd.DataFrame({"date": d, "y": y})
    >>> fd = pd.DataFrame({"date": d[132:], "f1": f1, "f2": f2})
    >>> faccuracy(yd, fd)
    """
    tsx_check_level(level)
    alpha = 1 - level
    a = tsx_forecast_align(y, py, stdpy, origin, names, level)
    yy = a["y"]
    n, m = yy.shape
    origin = a["origin"]
    s = tsx_series_index(series, a["names"])[0]
    cc = tsx_forecast_cols(s, m, a["nf"])
    cols = cc["py"]
    if origin >= n:
        tsx_no_overlap()
    tt = np.arange(origin + 1, n + 1)
    actual = yy[tt - 1, s - 1]
    tsx_check_overlap(actual, a["py"][np.ix_(tt - 1, cols)])
    zin = yy[:origin, s - 1] if origin > 0 else None
    maseden = nanmean(np.abs(np.diff(zin))) if zin is not None else np.nan
    ind = ~np.isnan(actual)
    tindx = int(np.sum(ind))
    ti = np.cumsum(ind) if ind.any() else np.ones(len(ind))
    na_h = np.full(len(tt), np.nan)

    def pinball(q, tau):
        with np.errstate(invalid="ignore"):
            return np.where(actual >= q, tau * (actual - q), (1 - tau) * (q - actual))

    tab = []
    hor = []
    with np.errstate(all="ignore"):
        for f in range(len(cols)):
            fc = a["py"][tt - 1, cols[f]]
            e = fc - actual
            # interval measures
            cover = width = score = pb_l = pb_u = na_h
            if a["bands"] is not None:
                lo = a["bands"][tt - 1, cc["lower"][f]].copy()
                up = a["bands"][tt - 1, cc["upper"][f]].copy()
                okb = ~np.isnan(actual) & ~np.isnan(lo) & ~np.isnan(up)
                lo[~okb] = np.nan
                up[~okb] = np.nan
                cover = np.where(okb, ((actual >= lo) & (actual <= up)).astype(float), np.nan)
                width = up - lo
                score = (width + 2 / alpha * (lo - actual) * (actual < lo)
                         + 2 / alpha * (actual - up) * (actual > up))
                pb_l = pinball(lo, alpha / 2)
                pb_u = pinball(up, 1 - alpha / 2)
            bias = np.nansum(e) / tindx
            mae = np.nansum(np.abs(e)) / tindx
            bias_h = tsx_nancumsum(e) / ti
            mae_h = tsx_nancumsum(np.abs(e)) / ti
            tab.append({
                "forecast": f + 1, "n": tindx, "bias": bias, "mae": mae,
                "bias_mae": abs(bias) + mae, "rmse": math.sqrt(np.nansum(e ** 2) / tindx),
                "mase": np.nan if zin is None else np.nansum(np.abs(e) / maseden) / tindx,
                "coverage": _mean_ok(cover), "range": _mean_ok(width), "mis": _mean_ok(score),
                "pinball_lower": _mean_ok(pb_l), "pinball_upper": _mean_ok(pb_u)})
            hor.append(pd.DataFrame({
                "forecast": f + 1, "t": tt, "actual": actual, "fcst": fc, "e": e,
                "bias": bias_h, "mae": mae_h, "bias_mae": np.abs(bias_h) + mae_h,
                "rmse": np.sqrt(tsx_nancumsum(e ** 2) / ti),
                "mase": na_h if zin is None else tsx_nancumsum(np.abs(e) / maseden) / ti,
                "coverage": _cummean_ok(cover), "range": _cummean_ok(width),
                "mis": _cummean_ok(score), "pinball_lower": _cummean_ok(pb_l),
                "pinball_upper": _cummean_ok(pb_u)}))
    tab = pd.DataFrame(tab)
    hor = pd.concat(hor, ignore_index=True)
    if a["dates"] is not None:
        hor.insert(2, "date", a["dates"][hor["t"].to_numpy() - 1])
    return tsx_result("faccuracy", call={"origin": origin, "series": s, "level": level},
                      series=a["names"][s - 1], table=tab, by_horizon=hor,
                      dates=None if a["dates"] is None else a["dates"][tt - 1])


def fcompare(y, py, origin=0, trunc=1, series=1, names=None):
    """Forecast comparison tests.

    For every pair of forecasts of one series, tests of the null hypothesis
    of equal accuracy based on squared errors (MSE) and on absolute errors
    (MAE): Diebold-Mariano (with ``trunc`` autocovariances in the long run
    variance of the loss differential), sign test and Wilcoxon signed rank
    test (exact for up to 15 non-zero differences, normal approximation
    without continuity correction otherwise). An error
    :class:`TsxNoOverlapError` is raised when the actual values and the
    forecasts do not overlap (see :func:`faccuracy`).

    Parameters
    ----------
    y, py, origin, series, names
        See :func:`faccuracy`.
    trunc : int
        Truncation lag of the long run variance of the Diebold-Mariano test
        (number of autocovariances). Default 1.

    Returns
    -------
    TsxResult
        Object of class ``tsx_fcompare`` with fields ``call``, ``series``,
        ``dates`` (dates of the forecasting sample for dated inputs,
        otherwise ``None``) and ``table``, a DataFrame with one row per pair
        of forecasts and loss function: ``f1``, ``f2``, ``loss`` (``"mse"``
        or ``"mae"``), ``dm``, ``p_dm``, ``sign``, ``p_sign``, ``wilcoxon``
        (sum of the ranks of the positive differences) and ``p_wilcoxon``.

    See Also
    --------
    TsxResult.text, faccuracy, fplot, toolforecast

    References
    ----------
    Diebold, F.X. and Mariano, R.S. (1995). Comparing predictive accuracy.
    *Journal of Business and Economic Statistics*, 13, 253-263.

    Wilcoxon, F. (1945). Individual comparisons by ranking methods.
    *Biometrics Bulletin*, 1, 80-83.

    Examples
    --------
    >>> y = np.log(load_data("airpas").to_numpy())
    >>> fcompare(y, np.column_stack([y[120:132], np.repeat(y[131], 12)]))
    """
    a = tsx_forecast_align(y, py, None, origin, names)
    yy = a["y"]
    n, m = yy.shape
    origin = a["origin"]
    s = tsx_series_index(series, a["names"])[0]
    cols = tsx_forecast_cols(s, m, a["nf"])["py"]
    nf = len(cols)
    if nf < 2:
        raise ValueError("At least two forecasts are needed.")
    if origin >= n:
        tsx_no_overlap()
    tt = np.arange(origin + 1, n + 1)
    nofs = n - origin
    trunc = min(tsx_check_int(trunc, "trunc", 0), nofs - 1)
    actual = yy[tt - 1, s - 1]
    fc = a["py"][np.ix_(tt - 1, cols)]
    tsx_check_overlap(actual, fc)
    e = fc - actual[:, None]
    tab = tsx_compare_losses({"mse": e ** 2, "mae": np.abs(e)}, trunc, nofs)
    return tsx_result("fcompare", call={"origin": origin, "trunc": trunc, "series": s},
                      series=a["names"][s - 1], table=tab,
                      dates=None if a["dates"] is None else a["dates"][tt - 1])


def tsx_compare_losses(loss, trunc, nofs):
    """Diebold-Mariano, sign and Wilcoxon tests for every pair of forecasts
    and every loss: 'loss' is a dict of matrices (periods x forecasts)."""
    nf = next(iter(loss.values())).shape[1]
    rows = []
    for i in range(nf - 1):
        for j in range(i + 1, nf):
            for name, lm in loss.items():
                li = lm[:, i]
                lj = lm[:, j]
                dm = tsx_dm_test(li - lj, trunc, nofs)
                sg = tsx_sign_test(li - lj, nofs)
                wi = tsx_signrank(li, lj)
                rows.append({"f1": i + 1, "f2": j + 1, "loss": name, "dm": dm[0],
                             "p_dm": dm[1], "sign": sg[0], "p_sign": sg[1],
                             "wilcoxon": wi[0], "p_wilcoxon": wi[1]})
    return pd.DataFrame(rows)


def tsx_dm_test(d, trunc, nofs):
    """Diebold-Mariano statistic and two sided p-value."""
    dt = d - nanmean(d)
    m1 = nanmean(d)
    f0 = nanvar(dt)
    nd = len(dt)
    for k in range(1, trunc + 1):
        f0 = f0 + 2 * np.nansum(dt[k:nd] * dt[:nd - k]) / nofs
    if np.isnan(f0):
        return (np.nan, np.nan)
    if f0 >= 0:
        stat = m1 / math.sqrt(f0 / nofs) if f0 > 0 else 0.0
        return (stat, 2 * stats.norm.sf(abs(stat)))
    return (np.inf, 0.0)


def tsx_sign_test(d, nofs):
    """Sign test (normal approximation)."""
    if np.all(~np.isnan(d) & (d == 0)):
        return (0.0, 1.0)
    with np.errstate(invalid="ignore"):
        n1 = np.sum(d > 0)
    stat = (n1 - 0.5 * nofs) / (0.5 * math.sqrt(nofs))
    return (stat, 2 * stats.norm.sf(abs(stat)))


def fplot(y, py, stdpy=None, origin=0, series=1, forecast=1, s=12, subsample=0, level=0.95,
          names=None):
    """Plot of actual values and forecasts.

    Actual values of one series with one or all its forecasts, their
    confidence bands and the forecast errors, optionally for a subperiod.
    The returned object holds the data to plot; ``plot()`` draws it.

    Parameters
    ----------
    y, py, stdpy, origin, series, level, names
        See :func:`faccuracy`.
    forecast : int or str
        Forecast to plot (``1..n``) or ``"all"``.
    s : int
        Length of the subperiods for the navigation (default 12).
    subsample : int
        ``0`` for the full sample or ``k`` for the k-th subperiod of length
        ``s``.

    Returns
    -------
    TsxResult
        Object of class ``tsx_fplot`` with fields ``call``, ``series``,
        ``time`` (row numbers from 1), ``actual``, ``forecasts`` (matrix),
        ``lower``, ``upper`` (matrices of bands ``py -/+ z * stdpy``, or
        ``None`` without ``stdpy``), ``errors`` (forecast minus actual for
        one forecast, absolute errors for all), ``origin`` and ``dates``
        (date of each row for dated inputs, otherwise ``None``).

    See Also
    --------
    TsxResult.plot, faccuracy, fcompare, toolforecast

    Examples
    --------
    >>> y = np.log(load_data("airpas").to_numpy())
    >>> p = fplot(y, np.column_stack([y[120:132], np.repeat(y[131], 12)]), forecast="all")
    >>> # dated forecasts after the end of the data (aligned by their dates)
    >>> y = np.log(load_data("airpas"))
    >>> fut = pd.Series(np.repeat(y.iloc[-1], 12),
    ...                 index=pd.period_range("1961-01", periods=12, freq="M"))
    >>> p = fplot(y, fut, s=24, subsample=6)
    >>> # with 90% intervals (standard deviations growing with the horizon)
    >>> p = fplot(y, fut, 0.03 * np.sqrt(np.arange(1, 13)), level=0.9, s=24, subsample=6)
    """
    a = tsx_forecast_align(y, py, stdpy, origin, names, level)
    yy = a["y"]
    n, m = yy.shape
    si = tsx_series_index(series, a["names"])[0]
    cc = tsx_forecast_cols(si, m, a["nf"])
    all_ = isinstance(forecast, str) and forecast.lower() == "all"
    if all_:
        fsel = list(range(1, a["nf"] + 1))
    else:
        try:
            f = int(forecast)
        except (TypeError, ValueError):
            f = -1
        if f < 1 or f > a["nf"]:
            raise ValueError("Invalid 'forecast'.")
        fsel = [f]
    s = min(tsx_check_int(s, "s"), n)
    nsub = math.ceil(n / s)
    subsample = int(min(max(0, round(subsample)), nsub))
    if subsample == 0:
        t = np.arange(1, n + 1)
    else:
        t = np.arange((subsample - 1) * s + 1, min(subsample * s, n) + 1)
    fidx = [f - 1 for f in fsel]
    fc = a["py"][:, cc["py"][fidx]]
    lower = upper = None
    if a["bands"] is not None:
        lower = a["bands"][:, cc["lower"][fidx]]
        upper = a["bands"][:, cc["upper"][fidx]]
    err = np.abs(yy[:, [si - 1]] - fc) if all_ else fc - yy[:, [si - 1]]
    return tsx_result("fplot",
                      call={"series": si, "forecast": "all" if all_ else fsel[0], "s": s,
                            "subsample": subsample, "n_subsamples": nsub, "level": level},
                      series=a["names"][si - 1], time=t, actual=yy[:, si - 1], forecasts=fc,
                      forecast_names=["F%d" % f for f in fsel], lower=lower, upper=upper,
                      errors=err, origin=a["origin"], dates=a["dates"])


# --- Text and plots (print() and plot() methods of R)

@text_method("faccuracy")
def tsx_text_faccuracy(x, digits=None):
    digits = 3 if digits is None else digits
    t = x["table"]
    t = t[[c for c in t.columns if not t[c].isna().all()]]
    lv = 0.95 if x["call"].get("level") is None else x["call"]["level"]
    notes = {
        "bias": "bias:          Mean Error (F - y)",
        "mae": "mae:           Mean Absolute Error",
        "bias_mae": "bias+mae:      |bias| + mae",
        "rmse": "rmse:          Root Mean Squared Error",
        "mase": "mase:          Mean Absolute Scaled Error (mae out sample / mae in sample)",
        "coverage": "coverage:      proportion of actual values inside the intervals"
                    " (nominal %s)" % tsx_format_g(lv),
        "range": "range:         mean width of the intervals",
        "mis": "mis:           Mean Interval Score (alpha = %s)" % tsx_format_g(1 - lv),
        "pinball_lower": "pinball_lower: pinball loss of the lower bound (quantile alpha / 2)",
        "pinball_upper": "pinball_upper: pinball loss of the upper bound (quantile 1 - alpha / 2)"}
    cols = [c for c in t.columns if c != "forecast"]
    return tsx_cat_block(
        title=["Forecasting Results", "Series " + x["series"], tsx_period_text(x["dates"])],
        notes=[notes[c] for c in notes if c in cols],
        table=tsx_format_table(t[cols], [0] + [digits] * (len(cols) - 1),
                               row_names=["F#%d" % f for f in t["forecast"]],
                               col_names=["bias+mae" if c == "bias_mae" else c for c in cols]))


@text_method("fcompare")
def tsx_text_fcompare(x, digits=None):
    digits = 4 if digits is None else digits
    out = ["-" * 60, "Forecast Accuracy Comparison Tests", "-" * 60, "Series: " + x["series"]]
    if x["dates"] is not None:
        out.append(tsx_period_text(x["dates"]))
    out += ["-" * 60, "H0: Forecasts have equal accuracy", "-" * 60,
            "DM:   Diebold and Mariano (1995) Test", "SIGN: Sign Test",
            "Wi:   Wilcoxon Signed-Rank Test",
            "Truncation value for DM test: %d" % x["call"]["trunc"], ""]
    titles = {"mse": "Table based on Squared Errors (MSE)",
              "mae": "Table based on Absolute Errors (MAE)"}
    tab = x["table"]
    for loss, title in titles.items():
        t = tab[tab["loss"] == loss]
        out += tsx_cat_block(
            title=title,
            table=tsx_format_table(t[["dm", "p_dm", "sign", "p_sign", "wilcoxon", "p_wilcoxon"]],
                                   digits,
                                   row_names=["F#%d vs F#%d:" % (a, b)
                                              for a, b in zip(t["f1"], t["f2"])],
                                   col_names=["DM", "P", "SIGN", "P", "Wi", "P"]))
        out.append("")
    return out


@plot_method("fplot")
def tsx_plot_fplot(x, fig):
    t = np.asarray(x["time"])
    fc = x["forecasts"]
    nf = fc.shape[1]
    cols = [col(c) for c in ("red", "darkgreen", "magenta3", "gold3", "blue", "cyan3")]
    cols = [cols[k % len(cols)] for k in range(nf)]
    all_ = x["call"]["forecast"] == "all"

    def finite_range(v):
        v = np.asarray(v, dtype=float).ravel()
        v = v[np.isfinite(v)]
        return (-0.1, 0.1) if len(v) == 0 else (v.min(), v.max())

    parts = [x["actual"], fc] + [b for b in (x["lower"], x["upper"]) if b is not None]
    yl = finite_range(np.concatenate([np.asarray(p, dtype=float).ravel() for p in parts]))
    dates = None if x["dates"] is None else x["dates"][t - 1]
    co = tsx_time_coords(dates, t)
    xo = None
    if x["origin"] > 0:
        xo = x["origin"] if x["dates"] is None else x["dates"][x["origin"] - 1]
    ax1, ax2 = fig.subplots(2, 1, sharex=True, gridspec_kw={"height_ratios": [3, 1]})
    ax1.plot(co["x"], x["actual"][t - 1], color=col("black"), label=x["series"])
    for k in range(nf):
        ax1.plot(co["x"], fc[t - 1, k], color=cols[k], label=x["forecast_names"][k])
        if x["lower"] is not None:
            ax1.plot(co["x"], x["lower"][t - 1, k], ":", color=cols[k])
            ax1.plot(co["x"], x["upper"][t - 1, k], ":", color=cols[k])
    if xo is not None:
        ax1.axvline(xo, color=col("black"), linewidth=2)
    tsx_xlim(ax1, co["xlim"])
    tsx_ylim(ax1, yl)
    ax1.set_ylabel("Series " + x["series"])
    ax1.set_title("Series %s: Series Plot, Forecast with confidence bands and Errors"
                  % x["series"])
    ax1.legend(loc="upper left", frameon=False, fontsize=8)
    e = x["errors"][t - 1, :]
    el = list(finite_range(e))
    if el[0] == el[1]:
        el = [-0.1, 0.1]
    if all_:
        el[0] = 0
    for k in range(nf):
        ax2.plot(co["x"], e[:, k], color=cols[k])
    if not all_:
        ax2.axhline(0, color=col("black"), linestyle=":")
    if xo is not None:
        ax2.axvline(xo, color=col("black"), linewidth=2)
    tsx_ylim(ax2, el)
    ax2.set_xlabel(co["lab"])
    ax2.set_ylabel("ABS(E)" if all_ else "Errors")
    fig.tight_layout()
