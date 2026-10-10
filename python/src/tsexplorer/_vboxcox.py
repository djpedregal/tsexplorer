import numpy as np
import pandas as pd

from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_series_index
from ._utils_math import (nanmean, nanmin, nansd, tsx_fminsearch, tsx_seq_by,
                          tsx_standardize)
from ._utils_plot import col, tsx_xlim, tsx_ylim
from ._utils_print import tsx_cat_block, tsx_format_table, tsx_num2str

AXISLAMBDAS = tuple(float(v) for v in tsx_seq_by(-1, 1, 0.1))


def vboxcox(y, lambdas=None, group=12, axislambdas=AXISLAMBDAS, series=1, names=None):
    """Box-Cox transformation.

    Estimates the Box-Cox parameter :math:`\\lambda` of each series with the
    method of Guerrero (1993): the series is divided into groups of
    ``group`` consecutive observations and :math:`\\lambda` minimises the
    coefficient of variation of :math:`s_j / \\bar{z}_j^{1 - \\lambda}`
    (standard deviation over mean of each group). It also evaluates, over a
    grid of values of :math:`\\lambda` (``axislambdas``), the standard
    deviation, the mean over standard deviation and the criterion of the
    transformed series, and returns the transformed data.

    Series with non-positive values are shifted by ``abs(min) + 1e-4``
    before the transformation.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    lambdas : float or list, optional
        Values of :math:`\\lambda` for the transformation of each series (the
        last one is repeated for the remaining series). If ``None`` they are
        estimated.
    group : int
        Number of observations per group (usually the seasonal period).
        Default 12.
    axislambdas : list
        Grid of :math:`\\lambda` values for the plot (default ``-1, -0.9,
        ..., 1``; ``None`` or empty for no grid).
    series : int or str
        Series used for the grid evaluation and the plot.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vboxcox`` with fields ``call``, ``series``,
        ``lambdas`` (dict with the estimated or supplied value of each
        series), ``estimated`` (bool), ``transformed`` (matrix of transformed
        series) and ``grid``, a DataFrame for the selected series with
        columns ``lambda``, ``sd``, ``mean_sd``, ``criterion`` (minus the
        coefficient of variation), and their standardised versions
        ``sd_std``, ``mean_sd_std``, ``criterion_std`` (as plotted), or
        ``None`` without grid.

    See Also
    --------
    TsxResult.text, TsxResult.plot, stdmean

    References
    ----------
    Box, G.E.P. and Cox, D.R. (1964). An analysis of transformations.
    *Journal of the Royal Statistical Society B*, 26, 211-252.

    Guerrero, V.M. (1993). Time-series analysis supported by power
    transformations. *Journal of Forecasting*, 12, 37-48.

    Examples
    --------
    >>> r = vboxcox(load_data("airpas"))
    >>> r.lambdas
    """
    y, names, _ = as_tsx_matrix(y, names)
    m = y.shape[1]
    group = tsx_check_int(group, "group", 2)
    shifted = np.column_stack([tsx_boxcox_shift(y[:, i]) for i in range(m)])
    estimated = lambdas is None or np.size(lambdas) == 0
    if estimated:
        lam = np.array([
            tsx_fminsearch(lambda l, z=shifted[:, i]: tsx_guerrero(l[0], z, group), 1)["par"][0]
            for i in range(m)])
    else:
        lam = np.atleast_1d(np.asarray(lambdas, dtype=float))[:m]
        lam = np.r_[lam, np.repeat(lam[-1], m - len(lam))]
    tr = shifted.copy()
    for i in range(m):
        tr[:, i] = tsx_boxcox(shifted[:, i], lam[i])
    i = tsx_series_index(series, names)[0]
    grid = None
    if axislambdas is not None and len(axislambdas) > 0:
        axislambdas = np.asarray(axislambdas, dtype=float)
        zi = shifted[:, i - 1]
        sd = np.full(len(axislambdas), np.nan)
        mean_sd = np.full(len(axislambdas), np.nan)
        crit = np.full(len(axislambdas), np.nan)
        for j, a in enumerate(axislambdas):
            zt = tsx_boxcox(zi, a)
            sd[j] = nansd(zt)
            mean_sd[j] = nanmean(zt) / sd[j]
            crit[j] = -tsx_guerrero(a, zi, group)
        grid = pd.DataFrame({"lambda": axislambdas, "sd": sd, "mean_sd": mean_sd,
                             "criterion": crit})
        std = tsx_standardize(grid[["sd", "mean_sd", "criterion"]].to_numpy())
        grid["sd_std"] = std[:, 0]
        grid["mean_sd_std"] = std[:, 1]
        grid["criterion_std"] = std[:, 2]
        axislambdas = [float(v) for v in axislambdas]
    return tsx_result("vboxcox",
                      call={"group": group, "axislambdas": axislambdas, "series": i},
                      series=names, lambdas=dict(zip(names, (float(v) for v in lam))),
                      estimated=estimated, transformed=tr, grid=grid)


def tsx_boxcox_shift(z):
    mn = nanmin(z)
    if mn <= 0:
        z = z + abs(mn) + 1e-4
    return z


def tsx_boxcox(z, lam):
    with np.errstate(all="ignore"):
        return np.log(z) if lam == 0 else (z ** lam - 1) / lam


def tsx_guerrero(lam, z, group):
    """Guerrero (1993) criterion (coefficient of variation)."""
    n = len(z)
    ny = n // group
    yr = z[n - ny * group:].reshape((group, ny), order="F")
    myr = nanmean(yr, axis=0)
    sd = nansd(yr, axis=0)
    yt = sd / myr ** (1 - lam)
    return nansd(yt) / nanmean(yt)


# --- Text and plots (print() and plot() methods of R)

@text_method("vboxcox")
def tsx_text_vboxcox(x, digits=None):
    digits = 4 if digits is None else digits
    return tsx_cat_block(
        title="Estimation of Box-Cox Lambdas:" if x["estimated"] else "Box-Cox Lambdas:",
        table=tsx_format_table([np.array(list(x["lambdas"].values()))], digits,
                               row_names=x["series"], col_names=["Lambdas"]))


@plot_method("vboxcox")
def tsx_plot_vboxcox(x, fig):
    g = x["grid"]
    if g is None:
        raise ValueError("No grid of lambdas to plot.")
    v = g[["sd_std", "mean_sd_std", "criterion_std"]].to_numpy()
    lam = g["lambda"].to_numpy()
    opt = [int(np.nanargmin(v[:, 0])), int(np.nanargmin(v[:, 1])), int(np.nanargmax(v[:, 2]))]
    lo, hi = np.nanmin(v) - 0.1, np.nanmax(v) + 0.1
    cols = ["blue", "red", "black"]
    ax = fig.add_subplot(1, 1, 1)
    for k in range(3):
        ax.plot(lam, v[:, k], "*-", color=col(cols[k]))
        ax.plot([lam[opt[k]], lam[opt[k]]], [lo, v[opt[k], k]], ":", color=col(cols[k]))
    tsx_xlim(ax, lam.min() - 0.1, lam.max() + 0.1)
    tsx_ylim(ax, lo, hi)
    ax.set_xlabel("Lambda")
    ax.set_ylabel("Normalised S.D., Mean/S.D. & L-Lik")
    ax.set_title("Series %s: S.D.(blue; %s), Mean/S.D.(red; %s) & L-Lik(black; %s)"
                 % (x["series"][x["call"]["series"] - 1], tsx_num2str(lam[opt[0]]),
                    tsx_num2str(lam[opt[1]]), tsx_num2str(lam[opt[2]])), fontsize=9)
