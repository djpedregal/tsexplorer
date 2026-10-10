# Internal numerical helpers.

import math
import warnings
from fractions import Fraction

import numpy as np
from scipy import stats

from ._utils_input import as_tsx_matrix


# --- Statistics ignoring missing values (nan without warnings for empty
# --- slices, as the functions of R with na.rm = TRUE).

def _quiet(fun, *args, **kwargs):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        with np.errstate(all="ignore"):
            return fun(*args, **kwargs)


def nanmean(x, axis=None):
    return _quiet(np.nanmean, x, axis=axis)


def nanmedian(x, axis=None):
    return _quiet(np.nanmedian, x, axis=axis)


def nansd(x, axis=None):
    return _quiet(np.nanstd, x, axis=axis, ddof=1)


def nanvar(x, axis=None):
    return _quiet(np.nanvar, x, axis=axis, ddof=1)


def nanmin(x, axis=None):
    return _quiet(np.nanmin, x, axis=axis)


def nanmax(x, axis=None):
    return _quiet(np.nanmax, x, axis=axis)


def tsx_mean(x):
    """mean() of R, which accumulates in extended precision: the exact mean
    (rational arithmetic) rounded to the nearest double, so that the results
    agree with those of R to the last bit in the printed tables."""
    x = np.asarray(x, dtype=float).ravel()
    n = len(x)
    if n == 0:
        return np.nan
    if not np.all(np.isfinite(x)):
        return float(np.mean(x))
    return float(sum(Fraction(v) for v in x.tolist()) / n)


def tsx_sd(x):
    """sd() of R (two passes in extended precision), computed with exact
    rational arithmetic."""
    x = np.asarray(x, dtype=float).ravel()
    n = len(x)
    if n < 2:
        return np.nan
    if not np.all(np.isfinite(x)):
        return float(np.std(x, ddof=1))
    fx = [Fraction(v) for v in x.tolist()]
    m = sum(fx) / n
    return math.sqrt(float(sum((v - m) ** 2 for v in fx) / (n - 1)))


def tsx_cumsum(x):
    """cumsum() of R (accumulation in extended precision), emulated with
    exact partial sums (Shewchuk's algorithm, as math.fsum)."""
    out = np.empty(len(x))
    parts = []
    for k, v in enumerate(np.asarray(x, dtype=float)):
        if not math.isfinite(v):
            out[k:] = np.cumsum(np.r_[math.fsum(parts), x[k:]])[1:]
            return out
        i = 0
        for y in parts:
            if abs(v) < abs(y):
                v, y = y, v
            hi = v + y
            lo = y - (hi - v)
            if lo:
                parts[i] = lo
                i += 1
            v = hi
        parts[i:] = [v]
        out[k] = math.fsum(parts)
    return out


def tsx_det(a):
    """Determinant (nan without warnings for matrices with missing values,
    as det() of R)."""
    with np.errstate(all="ignore"):
        return float(np.linalg.det(a))


def tsx_seq_by(start, stop, by):
    """Values from ``start`` to ``stop`` with increment ``by``, computed as
    ``seq(from, to, by = by)`` in R: ``from + (0:n) * by``, ``n = floor((to -
    from) / by + 1e-10)``, clamped to ``to``."""
    n = int(math.floor((stop - start) / by + 1e-10))
    x = start + np.arange(n + 1) * by
    return np.minimum(x, stop) if by > 0 else np.maximum(x, stop)


def tsx_delay(y, lags):
    """Matrix of lagged variables. Rows are t = maxlag+1, ..., T; block i
    holds y lagged lags[i] periods."""
    y = np.asarray(y, dtype=float)
    if y.ndim == 1:
        y = y.reshape(-1, 1)
    lags = [int(v) for v in np.atleast_1d(lags)]
    n, m = y.shape
    maxlag = max(lags)
    out = np.zeros((n - maxlag, m * len(lags)))
    for i, lag in enumerate(lags):
        out[:, i * m:(i + 1) * m] = y[maxlag - lag:n - lag, :]
    return out


def vdif(y, order=1, s=1):
    """Differencing of a vector of time series.

    Applies multiplicative difference operators
    :math:`\\prod_j (1 - B^{s_j})^{d_j}` to each series.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    order : int, list or 2-D array
        Difference orders. A vector applies the same multiplicative
        polynomials to every series; a matrix with one row per series allows
        different orders for each series (the last row is recycled).
    s : int, list or 2-D array
        Seasonal period of each polynomial (same layout as ``order``).

    Returns
    -------
    pandas.DataFrame
        Differenced data, with the names of the series as columns and
        without dates. The first ``r`` observations are lost, being ``r`` the
        largest total order of differencing among the series.

    See Also
    --------
    as_tsx_matrix

    Examples
    --------
    >>> y = np.log(load_data("airpas"))
    >>> vdif(y, [1, 1], [1, 12]).head()
    >>> vdif(pd.concat([y, y], axis=1), [[1, 0], [1, 1]], [1, 12]).head()
    """
    import pandas as pd

    y, names, _ = as_tsx_matrix(y, trim=False)
    n, m = y.shape
    order = tsx_rows_as_series(order, m)
    s = tsx_rows_as_series(s, m)
    if s.shape[1] < order.shape[1]:
        s = np.hstack([s, np.ones((m, order.shape[1] - s.shape[1]))])
    polys = []
    la = 0
    for i in range(m):
        a = np.array([1.0])
        for j in range(order.shape[1]):
            for _ in range(int(order[i, j])):
                if s[i, j] > 0:
                    a = tsx_conv(a, np.r_[1.0, np.zeros(int(s[i, j]) - 1), -1.0])
        polys.append(a)
        la = max(la, len(a))
    if la > n:
        raise ValueError("Not enough data for the required differences.")
    out = np.full((n - la + 1, m), np.nan)
    rows = np.arange(la - 1, n)
    for i in range(m):
        a = polys[i]
        acc = 0.0
        for k in range(len(a)):
            acc = acc + a[k] * y[rows - k, i]
        out[:, i] = acc
    return pd.DataFrame(out, columns=names)


def tsx_rows_as_series(x, m):
    """Expand a vector/matrix of per-series options to m rows (last row
    recycled)."""
    x = np.asarray(x, dtype=float)
    if x.ndim < 2:
        x = x.reshape(1, -1)
    if x.shape[0] < m:
        x = np.vstack([x] + [x[-1:, :]] * (m - x.shape[0]))
    return x[:m, :]


def tsx_conv(a, b):
    """Polynomial multiplication."""
    out = np.zeros(len(a) + len(b) - 1)
    for i in range(len(a)):
        out[i:i + len(b)] = out[i:i + len(b)] + a[i] * b
    return out


def tsx_standardize(y):
    """Standardisation of each column (mean 0, standard deviation 1, with
    standard deviation computed with T - 1). Zero standard deviations are
    replaced by one."""
    y = np.asarray(y, dtype=float)
    vec = y.ndim == 1
    if vec:
        y = y.reshape(-1, 1)
    mz = nanmean(y, axis=0)
    sz = nansd(y, axis=0)
    sz = np.where(~np.isnan(sz) & (sz == 0), 1.0, sz)
    out = (y - mz) / sz
    return out[:, 0] if vec else out


def tsx_nanprod(a, b):
    """Matrix product ignoring missing products. Returns the product and the
    number of non missing terms of each element."""
    a = np.atleast_2d(np.asarray(a, dtype=float))
    b = np.asarray(b, dtype=float)
    if b.ndim == 1:
        b = b.reshape(-1, 1)
    a0 = np.where(np.isnan(a), 0.0, a)
    b0 = np.where(np.isnan(b), 0.0, b)
    n = (~np.isnan(a)).astype(float) @ (~np.isnan(b)).astype(float)
    return a0 @ b0, n


def tsx_nancov(y):
    """Covariance matrix with pairwise deletion of missing values."""
    y = np.asarray(y, dtype=float)
    if y.ndim == 1:
        y = y.reshape(-1, 1)
    y = y - nanmean(y, axis=0)
    prod, n = tsx_nanprod(y.T, y)
    with np.errstate(all="ignore"):
        return prod / (n - 1)


def tsx_nancorr(y):
    """Correlation matrix with pairwise deletion of missing values."""
    return tsx_nancov(tsx_standardize(y))


def meda(y):
    """Median absolute deviation with respect to the median.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).

    Returns
    -------
    numpy.ndarray
        MEDA of each series (missing values are ignored).

    See Also
    --------
    stdmean, sumstats

    Examples
    --------
    >>> meda(load_data("airpas"))
    """
    y, _, _ = as_tsx_matrix(y, trim=False)
    out = np.full(y.shape[1], np.nan)
    for i in range(y.shape[1]):
        x = y[:, i]
        out[i] = nanmedian(np.abs(x - nanmedian(x)))
    return out


def tsx_prctile(y, p):
    """Percentiles (equivalent to ``quantile(type = 5)`` of R inside the
    range of the data, clamped outside). Returns a matrix with one row per
    percentile and one column per series."""
    y = np.asarray(y, dtype=float)
    if y.ndim == 1:
        y = y.reshape(-1, 1)
    p = np.atleast_1d(np.asarray(p, dtype=float))
    out = np.full((len(p), y.shape[1]), np.nan)
    for i in range(y.shape[1]):
        zi = np.sort(y[~np.isnan(y[:, i]), i])
        n = len(zi)
        if n == 0:
            continue
        x = np.r_[0.0, 100.0 * (np.arange(1, n + 1) - 0.5) / n, 100.0]
        out[:, i] = np.interp(p, x, np.r_[zi[0], zi, zi[-1]])
    return out


def tsx_interpol(x, y, xi, limits=None):
    """Linear interpolation in the grid (x, y); linear extrapolation from the
    two extreme points outside the grid; result clamped to ``limits``."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    if np.isnan(xi) or np.any(np.isnan(x)):
        return np.nan
    keep = np.r_[np.nonzero(np.diff(x) != 0)[0], len(x) - 1]
    x = x[keep]
    y = y[keep]
    n = len(x)
    if xi < x[0]:
        b = np.linalg.solve(np.array([[1.0, x[0]], [1.0, x[1]]]), y[0:2])
        yi = b[0] + b[1] * xi
    elif xi > x[n - 1]:
        b = np.linalg.solve(np.array([[1.0, x[n - 2]], [1.0, x[n - 1]]]), y[n - 2:n])
        yi = b[0] + b[1] * xi
    else:
        o = np.argsort(x, kind="stable")
        yi = np.interp(xi, x[o], y[o])
    if limits is not None:
        yi = min(max(yi, limits[0]), limits[1])
    return float(yi)


def tsx_skewness(x):
    """Skewness (biased version, divisor T)."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    d = x - tsx_mean(x)
    return tsx_mean(d ** 3) / tsx_mean(d ** 2) ** 1.5


def tsx_kurtosis(x):
    """Kurtosis (biased version, divisor T)."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    d = x - tsx_mean(x)
    return tsx_mean(d ** 4) / tsx_mean(d ** 2) ** 2


def tsx_ols(y, x):
    """Ordinary least squares returning what the tests of the package need:
    ``beta``, ``ixx`` (inverse of X'X), residuals ``e`` and ``sse``."""
    ixx = np.linalg.inv(x.T @ x)
    beta = ixx @ (x.T @ y)
    e = y - x @ beta
    return {"beta": beta, "ixx": ixx, "e": e, "sse": float(np.sum(e ** 2))}


def _lstsq(x, y):
    return np.linalg.lstsq(x, y, rcond=None)[0]


def tsx_mvar(y, order, const=True, partial=False):
    """Least squares estimation of a VAR model with lags ``order``.

    ``const``: include a constant; ``partial=True`` regresses y(t - max(order)
    - 1) on the same regressors (used for partial lag autocorrelations).
    Missing values are handled with :func:`tsx_nanprod`.
    """
    y = np.asarray(y, dtype=float)
    if y.ndim == 1:
        y = y.reshape(-1, 1)
    n, m = y.shape
    order = [int(v) for v in np.atleast_1d(order)]
    if len(order) > 0 and order[0] == 0:
        order = order[1:]
    if len(order) == 0:
        return None
    lags = [max(order) + 1] + order if partial else [0] + order
    lagy = tsx_delay(y, lags)
    x = lagy[:, m:]
    if const:
        x = np.hstack([x, np.ones((x.shape[0], 1))])
    yy = lagy[:, :m]
    if np.isnan(y).any():
        inv_xx = np.linalg.inv(tsx_nanprod(x.T, x)[0])
        p = inv_xx @ tsx_nanprod(x.T, yy)[0]
        e = yy - tsx_nanprod(x, p)[0]
        s = tsx_nanprod(e.T, e)[0]
    else:
        inv_xx = np.linalg.inv(x.T @ x)
        p = _lstsq(x, yy)
        e = yy - x @ p
        s = e.T @ e
    sigma = s / n
    cov_p = np.kron(sigma, inv_xx)
    se_p = np.sqrt(np.diag(cov_p)).reshape(p.shape, order="F")
    npar = (lagy.shape[1] - m) / m
    k = npar * m * m + m
    with np.errstate(all="ignore"):
        ldet = np.log(tsx_det(sigma))
    aic = (n * ldet + 2 * k) / n
    sbc = (n * ldet + k * np.log(n)) / n
    return {"p": p, "se_p": se_p, "sigma": sigma, "aic": aic, "sbc": sbc, "e": e,
            "cov_p": cov_p, "inv_xx": inv_xx, "lagy": lagy, "x": x}


def tsx_auxvarsbc(y, order):
    """Information criteria of a VAR(order) with constant."""
    y = np.asarray(y, dtype=float)
    if y.ndim == 1:
        y = y.reshape(-1, 1)
    n, m = y.shape
    lagy = y if order == 0 else tsx_delay(y, range(order + 1))
    x = np.hstack([lagy[:, m:], np.ones((lagy.shape[0], 1))])
    yy = lagy[:, :m]
    if np.isnan(y).any():
        if order == 0:
            e = y
        else:
            b = np.linalg.inv(tsx_nanprod(x.T, x)[0]) @ tsx_nanprod(x.T, yy)[0]
            e = yy - tsx_nanprod(x, b)[0]
        s = tsx_nanprod(e.T, e)[0]
    else:
        e = y if order == 0 else yy - x @ _lstsq(x, yy)
        s = e.T @ e
    sigma = s / n
    npar = (lagy.shape[1] - m) / m
    with np.errstate(all="ignore"):
        ldet = np.log(tsx_det(sigma))
        k = npar * m * m + m
        return {"sigma": sigma,
                "fpe": ldet + np.log((n + k) / (n - k)),
                "aic": ldet + 2 * k / n,
                "aicc": ldet + (2 * k + 2) / (n - k - 2),
                "sbc": ldet + k * np.log(n) / n,
                "hqc": ldet + 2 * k * np.log(np.log(n)) / n,
                "e": e}


def tsx_acf_pacf(x, ncoef, npar=0):
    """Sample ACF, PACF, Ljung-Box and Monti tests of one series (common core
    of vident() and nltests())."""
    x = np.asarray(x, dtype=float).ravel()
    n = len(x)
    zs = tsx_standardize(x)
    sacf = np.zeros(ncoef)
    if not np.isnan(zs).any():
        den = np.sum(zs ** 2)
        for k in range(1, ncoef + 1):
            sacf[k - 1] = np.sum(zs[:n - k] * zs[k:]) / den
    else:
        for k in range(1, ncoef + 1):
            pr = zs[k:] * zs[:n - k]
            sacf[k - 1] = np.nansum(pr) / np.sum(~np.isnan(pr))
    seacf = np.zeros(ncoef)
    seacf[0] = 1 / np.sqrt(n)
    if ncoef > 1:
        seacf[1:] = np.sqrt((1 + 2 * np.cumsum(sacf[:ncoef - 1] ** 2)) / n)
    spacf = tsx_durbin_levinson(sacf)
    sepacf = np.full(ncoef, 1 / np.sqrt(n))
    lags = np.arange(1, ncoef + 1)
    df = lags - npar
    q = n * (n + 2) * np.cumsum(sacf ** 2 / (n - lags))
    qmt = n * (n + 2) * np.cumsum(spacf ** 2 / (n - lags))
    pq = np.where(df > 0, stats.chi2.sf(q, np.maximum(df, 1)), np.nan)
    pqmt = np.where(df > 0, stats.chi2.sf(qmt, np.maximum(df, 1)), np.nan)
    return {"sacf": sacf, "spacf": spacf, "se_acf": seacf, "se_pacf": sepacf,
            "q": q, "p_q": pq, "q_mt": qmt, "p_q_mt": pqmt}


def tsx_durbin_levinson(r):
    """Durbin-Levinson recursion: partial autocorrelations from
    autocorrelations."""
    r = np.asarray(r, dtype=float)
    nc = len(r)
    spacf = r.copy()
    fi = np.zeros(nc)
    fi[0] = r[0]
    for i in range(1, nc):
        fi[i] = (r[i] - np.sum(fi[:i] * r[:i][::-1])) / (1 - np.sum(fi[:i] * r[:i]))
        spacf[i] = fi[i]
        fi[:i] = fi[:i] - fi[i] * fi[:i][::-1]
    return spacf


def tsx_signif_marks(x, lim=2):
    """Marks '+' (> lim), '-' (< -lim), '.' otherwise and '@' for NA."""
    x = np.asarray(x, dtype=float)
    out = np.where(x > lim, "+", np.where(x < -lim, "-", "."))
    out[np.isnan(x)] = "@"
    return out


def tsx_fminsearch(fun, x0, tol_x=1e-4, tol_fun=1e-4, max_iter=None, max_fun_evals=None,
                   *args):
    """Nelder-Mead simplex (Lagarias et al., 1998) as ``fminsearch`` of
    MATLAB: initial simplex with 5% perturbations (0.00025 for zero
    components), standard coefficients and stopping rules on ``tol_x`` and
    ``tol_fun``."""
    x0 = np.atleast_1d(np.asarray(x0, dtype=float))
    n = len(x0)
    if max_iter is None:
        max_iter = 200 * n
    if max_fun_evals is None:
        max_fun_evals = 200 * n
    rho, chi, psi, sigma = 1.0, 2.0, 0.5, 0.5
    eps = np.finfo(float).eps
    v = np.tile(x0.reshape(-1, 1), (1, n + 1))
    fv = np.zeros(n + 1)
    fv[0] = fun(x0, *args)
    for j in range(n):
        y = x0.copy()
        y[j] = 1.05 * y[j] if y[j] != 0 else 0.00025
        v[:, j + 1] = y
        fv[j + 1] = fun(y, *args)
    o = np.argsort(fv, kind="stable")
    fv = fv[o]
    v = v[:, o]
    it = 1
    nfev = n + 1
    while nfev < max_fun_evals and it < max_iter:
        if (np.max(np.abs(fv[0] - fv[1:])) <= max(tol_fun, 10 * eps * fv[0]) and
                np.max(np.abs(v[:, 1:] - v[:, [0]])) <= max(tol_x, 10 * eps * np.max(v[:, 0]))):
            break
        xbar = np.mean(v[:, :n], axis=1)
        xr = (1 + rho) * xbar - rho * v[:, n]
        fxr = fun(xr, *args)
        nfev += 1
        shrink = False
        if fxr < fv[0]:
            xe = (1 + rho * chi) * xbar - rho * chi * v[:, n]
            fxe = fun(xe, *args)
            nfev += 1
            if fxe < fxr:
                v[:, n] = xe
                fv[n] = fxe
            else:
                v[:, n] = xr
                fv[n] = fxr
        elif fxr < fv[n - 1]:
            v[:, n] = xr
            fv[n] = fxr
        elif fxr < fv[n]:
            xc = (1 + psi * rho) * xbar - psi * rho * v[:, n]
            fxc = fun(xc, *args)
            nfev += 1
            if fxc <= fxr:
                v[:, n] = xc
                fv[n] = fxc
            else:
                shrink = True
        else:
            xcc = (1 - psi) * xbar + psi * v[:, n]
            fxcc = fun(xcc, *args)
            nfev += 1
            if fxcc < fv[n]:
                v[:, n] = xcc
                fv[n] = fxcc
            else:
                shrink = True
        if shrink:
            for j in range(1, n + 1):
                v[:, j] = v[:, 0] + sigma * (v[:, j] - v[:, 0])
                fv[j] = fun(v[:, j], *args)
            nfev += n
        o = np.argsort(fv, kind="stable")
        fv = fv[o]
        v = v[:, o]
        it += 1
    return {"par": v[:, 0].copy(), "value": fv[0], "iterations": it, "fun_evals": nfev}


def tsx_hist(x, bins):
    """Histogram counts with ``bins`` equally spaced bins between min and
    max (as ``hist`` of MATLAB)."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    mn = np.min(x)
    mx = np.max(x)
    if mn == mx:
        mn = mn - bins / 2
        mx = mx + bins / 2
    breaks = np.linspace(mn, mx, bins + 1)
    # findInterval(x, breaks, rightmost.closed = TRUE, all.inside = TRUE)
    idx = np.searchsorted(breaks, x, side="right")
    idx = np.clip(idx, 1, bins)
    counts = np.bincount(idx - 1, minlength=bins).astype(float)
    return {"breaks": breaks, "counts": counts, "mids": (breaks[1:] + breaks[:-1]) / 2}


def tsx_ksdensity(x, at):
    """Kernel density estimate with normal kernel and bandwidth
    sigma * (4 / (3 n))^(1 / 5), sigma = MAD / 0.6745 (as ``ksdensity`` of
    MATLAB)."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    at = np.atleast_1d(np.asarray(at, dtype=float))
    n = len(x)
    sig = np.median(np.abs(x - np.median(x))) / 0.6745
    if sig <= 0:
        sig = np.max(x) - np.min(x)
    h = sig * (4 / (3 * n)) ** (1 / 5) if sig > 0 else 1.0
    return np.mean(stats.norm.pdf((at[:, None] - x[None, :]) / h), axis=1) / h


def tsx_mode(x):
    """Most frequent value (the smallest one in case of ties)."""
    x = np.asarray(x, dtype=float)
    if len(x) == 0:
        return np.nan
    vals, counts = np.unique(x, return_counts=True)
    return vals[np.argmax(counts)]


def tsx_nancumsum(x):
    """Cumulative sum skipping missing values (kept as NA)."""
    x = np.asarray(x, dtype=float)
    out = np.full(len(x), np.nan)
    ok = ~np.isnan(x)
    out[ok] = np.cumsum(x[ok])
    return out


def tsx_eps(x):
    """Spacing of floating point numbers: distance from abs(x) to the next
    larger double."""
    x = np.abs(np.asarray(x, dtype=float))
    out = np.full(x.shape, 2.0 ** -1074)
    with np.errstate(invalid="ignore"):
        nz = (x > 0) & np.isfinite(x)
    out[nz] = 2.0 ** (np.floor(np.log2(x[nz])) - 52)
    return out


def tsx_signrank(x, y):
    """Wilcoxon signed rank test of paired samples (ties within a tolerance,
    as ``signrank`` of MATLAB): returns the sum of ranks of positive
    differences and the two sided p-value (exact for up to 15 non-zero
    differences, normal approximation without continuity correction
    otherwise)."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    d = x - y
    epsd = tsx_eps(x) + tsx_eps(y)
    ok = ~np.isnan(d)
    d = d[ok]
    epsd = epsd[ok]
    if len(d) == 0:
        return np.array([np.nan, np.nan])
    nz = np.abs(d) > epsd
    d = d[nz]
    epsd = epsd[nz]
    n = len(d)
    if n == 0:
        return np.array([0.0, 1.0])
    # mid ranks of |d| with ties (within tolerance) and tie adjustment
    ad = np.abs(d)
    o = np.argsort(ad, kind="stable")
    sx = ad[o]
    se = epsd[o]
    ranks = np.zeros(n)
    tieadj = 0.0
    k = 0
    while k < n:
        j = k
        while j < n - 1 and sx[j] + se[j] >= sx[j + 1] - se[j + 1]:
            j += 1
        ranks[k:j + 1] = (k + 1 + j + 1) / 2
        nt = j - k + 1
        if nt > 1:
            tieadj += nt * (nt - 1) * (nt + 1) / 2
        k = j + 1
    r = np.zeros(n)
    r[o] = ranks
    w = float(np.sum(r[d > 0]))
    if n <= 15:
        p = min(1.0, 2 * tsx_signrank_exact(r, w))
    else:
        z = (w - n * (n + 1) / 4) / math.sqrt((n * (n + 1) * (2 * n + 1) - tieadj) / 24)
        p = 2 * stats.norm.cdf(-abs(z))
    return np.array([w, p])


def tsx_signrank_exact(v, w):
    """Probability of the smaller tail of the signed rank statistic by
    counting subsets of ranks."""
    v = np.sort(np.asarray(v, dtype=float))
    n = len(v)
    maxw = n * (n + 1) / 2
    if w > maxw / 2:
        w = maxw - w
    if np.any(v != np.floor(v)):
        v = np.round(2 * v)
        w = round(2 * w)
    w = int(math.floor(w))
    cnt = np.zeros(w + 1)
    cnt[0] = 1
    top = 1
    for vj in v[v <= w]:
        vj = int(vj)
        newtop = min(top + vj, w + 1)
        start = min(vj, w + 1) + 1
        hi = np.arange(start, newtop + 1) - 1 if start <= newtop else np.arange(0)
        lo = np.arange(len(hi))
        cnt[hi] = cnt[hi] + cnt[lo]
        top = newtop
    return float(np.sum(cnt) / 2.0 ** n)
