import math

import numpy as np
import pandas as pd

from ._result import plot_method, text_method, tsx_result
from ._utils_input import as_tsx_matrix, tsx_check_int, tsx_series_index
from ._utils_math import nanmean, tsx_mvar, tsx_seq_by
from ._utils_plot import col, tsx_period_axis, tsx_xlim, tsx_ylim
from ._utils_print import tsx_cat_block, tsx_format_table


def vcumperiod(y, series=1, names=None):
    """Cumulative periodogram.

    Normalised cumulative periodogram of one series with the 1% and 5%
    Kolmogorov-Smirnov bands of the white noise hypothesis.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vcumperiod`` with fields ``call``, ``series``,
        ``table`` (DataFrame with columns ``freq``, frequency in cycles per
        period from 0 to 0.5, and ``cum_periodogram``) and ``bands`` (dict
        with the half width of the 1% and 5% bands, ``p01`` and ``p05``).

    See Also
    --------
    TsxResult.plot, vspectrum, vident

    References
    ----------
    Box, G.E.P., Jenkins, G.M., Reinsel, G.C. and Ljung, G.M. (2015). *Time
    Series Analysis: Forecasting and Control*, 5th ed. Wiley.

    Examples
    --------
    >>> vcumperiod(vdif(np.log(load_data("airpas")), [1, 1], [1, 12]))
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    i = tsx_series_index(series, names)[0]
    z = y[:, i - 1] - nanmean(y[:, i - 1])
    t2 = n // 2
    w = 2 * np.pi * np.arange(t2 + 1) / n
    per = tsx_periodogram(z, w)
    cum = np.cumsum(per)
    if not np.isnan(cum[-1]):
        cum = cum / cum[-1]
    return tsx_result("vcumperiod", call={"series": i}, series=names[i - 1],
                      table=pd.DataFrame({"freq": w / (2 * np.pi), "cum_periodogram": cum}),
                      bands={"p01": 1.63 / math.sqrt(t2), "p05": 1.36 / math.sqrt(t2)})


def tsx_periodogram(z, w):
    """Periodogram ordinates 2/T |sum z_t exp(-i w t)|^2 (missing values
    skipped)."""
    n = len(z)
    tt = np.arange(1, n + 1)
    ok = ~np.isnan(z)
    arg = np.outer(w, tt[ok])
    a = np.cos(arg) @ z[ok]
    b = np.sin(arg) @ z[ok]
    return 2 / n * (a ** 2 + b ** 2)


def vspectrum(y, smooth=1, xlog=(False, True), series=1, names=None):
    """Spectrum, cross spectrum, gains and coherence.

    Periodogram of one series, smoothed with a triangular window of length
    ``smooth``, or, for two series, the gains and squared coherence computed
    from the smoothed cross periodogram. The periodogram is :math:`|\\sum_t
    z_t e^{-i\\omega t}|^2 / (2\\pi T)` at the Fourier frequencies; near the
    frequencies 0 and :math:`\\pi` the smoothing window uses the symmetry of
    the periodogram.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    smooth : int
        Length of the triangular smoothing window (an even value is
        increased by one; 1 means no smoothing). Default 1.
    xlog : tuple of two bool
        Logarithmic scale for the frequency (period) axis and for the power
        axis in the plot. Default ``(False, True)``.
    series : int, str or list
        One series (number from 1 or name) or two series for the cross
        spectrum.
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_vspectrum`` with fields ``call``, ``series``
        (list with one or two names) and ``table``, a DataFrame with column
        ``freq`` (radians, from 0 to pi) and

        * one series: ``periodogram`` and ``spectrum`` (smoothed),
        * two series: ``cross_amplitude`` (modulus of the smoothed cross
          spectrum), ``spectrum1``, ``spectrum2`` (smoothed), ``gain12``
          (cross amplitude over the spectrum of the first series),
          ``gain21`` and ``coherence`` (squared coherence).

    See Also
    --------
    TsxResult.plot, varspectrum, vcumperiod

    Examples
    --------
    >>> vspectrum(vdif(np.log(load_data("airpas"))), smooth=5)
    >>> vspectrum(vdif(np.log(load_data("lydia_pinkham"))), smooth=7, series=[1, 2])
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    smooth = max(1, min(n // 2, tsx_check_int(smooth, "smooth")))
    if smooth % 2 == 0:
        smooth += 1
    idx = tsx_series_index(series, names)
    if len(idx) > 2:
        idx = idx[:2]
    sp = tsx_mspectrum(y[:, [i - 1 for i in idx]])
    w = sp["w"]
    even = n % 2 == 0
    if len(idx) == 1 or idx[0] == idx[1]:
        per = np.real(sp["i"][0, 0, :])
        tab = pd.DataFrame({"freq": w, "periodogram": per,
                            "spectrum": np.real(tsx_smooth_triangular(per, smooth, even))})
        idx = idx[:1]
    else:
        sm = [tsx_smooth_triangular(v, smooth, even)
              for v in (sp["i"][0, 1, :], sp["i"][0, 0, :], sp["i"][1, 1, :])]
        a = np.abs(sm[0])
        s1 = np.real(sm[1])
        s2 = np.real(sm[2])
        tab = pd.DataFrame({"freq": w, "cross_amplitude": a, "spectrum1": s1, "spectrum2": s2,
                            "gain12": a / s1, "gain21": a / s2, "coherence": a ** 2 / (s1 * s2)})
    return tsx_result("vspectrum", call={"smooth": smooth, "xlog": _xlog(xlog), "series": idx},
                      series=[names[i - 1] for i in idx], table=tab)


def _xlog(xlog):
    v = [bool(b) for b in np.atleast_1d(xlog)]
    return [v[k % len(v)] for k in range(2)]


def tsx_mspectrum(z):
    """Periodogram matrices I[:, :, j] = conj(F_j) F_j' / (2 pi T) at the
    Fourier frequencies w_j = 2 pi j / T, j = 0, ..., floor(T / 2). Missing
    values are skipped in the discrete Fourier transform."""
    z = np.asarray(z, dtype=float)
    if z.ndim == 1:
        z = z.reshape(-1, 1)
    n, m = z.shape
    nw = n // 2 + 1
    w = 2 * np.pi * np.arange(nw) / n
    tt = np.arange(1, n + 1)
    f = np.zeros((m, nw), dtype=complex)
    for k in range(m):
        ok = ~np.isnan(z[:, k])
        f[k, :] = np.exp(-1j * np.outer(w, tt[ok] - 1)) @ z[ok, k]
    out = np.zeros((m, m, nw), dtype=complex)
    for j in range(nw):
        out[:, :, j] = np.outer(np.conj(f[:, j]), f[:, j])
    for k in range(m):
        out[k, k, :] = np.real(out[k, k, :])
    return {"i": out / (2 * np.pi * n), "w": w}


def tsx_smooth_triangular(x, smooth, even=True):
    """Triangular smoothing: centred moving average with weights 1, 2, ...,
    (L + 1) / 2, ..., 2, 1 (normalised). x holds the (cross) periodogram at
    the frequencies 2 pi j / T, j = 0, ..., floor(T/2). At both ends the
    periodogram is extended by symmetry, I(-w) = conj(I(w)) and I(pi + w) =
    conj(I(pi - w)). 'even' indicates whether T is even (the last frequency
    is then pi)."""
    if smooth <= 1:
        return x
    if smooth % 2 == 0:
        smooth += 1
    inc = 2 / (smooth + 1)
    half = tsx_seq_by(inc, 1 - inc / 2, inc)
    b = np.r_[half, 1.0, half[::-1]]
    b = b / np.sum(b)
    lb = (len(b) - 1) // 2
    n = len(x)
    if lb > n - 2:
        raise ValueError("The smoothing window is too long for the sample size.")
    left = np.conj(x[1:lb + 1][::-1])
    if even:
        right = np.conj(x[np.arange(n - 1, n - lb - 1, -1) - 1])
    else:
        right = np.conj(x[np.arange(n, n - lb, -1) - 1])
    xp = np.r_[left, x, right]
    out = np.array(x, copy=True)
    for k in range(n):
        out[k] = np.sum(b * xp[k:k + 2 * lb + 1][::-1])
    return out


def varspectrum(y, order=16, nfreq=None, xlog=(False, True), series=1, names=None):
    """Autoregressive spectrum.

    Spectrum of an AR model of order ``order`` (with constant) fitted by
    least squares to one series, :math:`f(\\omega) = \\sigma^2 / (2\\pi) |1 /
    \\phi(e^{-i\\omega})|^2`, in the same scale as the periodogram of
    :func:`vspectrum`.

    Parameters
    ----------
    y : array_like, pandas.Series or pandas.DataFrame
        Time series data (see :func:`as_tsx_matrix`).
    order : int
        Order of the AR model. Default 16 (limited to ``T / 2``).
    nfreq : int, optional
        Number of frequencies in ``[0, pi)``. ``0`` uses the Fourier
        frequencies ``2 pi j / T``; values below 10 are replaced by
        ``floor(T / 2)``. Default ``floor(T / 2)``.
    xlog : tuple of two bool
        Logarithmic scale for the frequency (period) axis and for the power
        axis in the plot. Default ``(False, True)``.
    series : int or str
        Series to analyse (number from 1 or name).
    names : str or list of str, optional
        Names of the series.

    Returns
    -------
    TsxResult
        Object of class ``tsx_varspectrum`` with fields ``call``,
        ``series``, ``ar`` (estimated AR coefficients), ``sigma2``
        (innovation variance) and ``table`` (DataFrame with columns
        ``freq``, radians, and ``spectrum``).

    See Also
    --------
    TsxResult.plot, vspectrum

    Examples
    --------
    >>> varspectrum(vdif(np.log(load_data("airpas"))), order=14)
    """
    y, names, _ = as_tsx_matrix(y, names)
    n = y.shape[0]
    t2 = n // 2
    if nfreq is None:
        nfreq = t2
    if nfreq == 0:
        freq = 2 * np.pi * np.arange(t2 + 1) / n
    else:
        if nfreq < 10:
            nfreq = t2
        freq = tsx_seq_by(0, np.pi - np.pi / nfreq, np.pi / nfreq)
    order = max(1, min(t2, tsx_check_int(order, "order")))
    i = tsx_series_index(series, names)[0]
    v = tsx_mvar(y[:, [i - 1]], range(1, order + 1), const=True)
    ar = v["p"][:order, 0]
    k = np.arange(1, order + 1)
    h = np.array([1 / abs(1 - np.sum(ar * np.exp(-1j * w * k))) ** 2 for w in freq])
    sigma2 = float(v["sigma"][0, 0])
    return tsx_result("varspectrum",
                      call={"order": order, "nfreq": nfreq, "xlog": _xlog(xlog), "series": i},
                      series=names[i - 1], ar=ar, sigma2=sigma2,
                      table=pd.DataFrame({"freq": freq, "spectrum": sigma2 / (2 * np.pi) * h}))


# --- Text and plots (print() and plot() methods of R)

@text_method("vcumperiod")
def tsx_text_vcumperiod(x, digits=None):
    d = 4 if digits is None else digits
    return tsx_cat_block(title="Series %s: Cumulative Periodogram" % x["series"],
                         notes="Band half width: 1%% %.4f; 5%% %.4f" % (x["bands"]["p01"],
                                                                      x["bands"]["p05"]),
                         table=tsx_format_table(x["table"], d,
                                                col_names=["Frequency", "Cum. Power"]))


@plot_method("vcumperiod")
def tsx_plot_vcumperiod(x, fig):
    t = x["table"]
    b1, b2 = x["bands"]["p01"], x["bands"]["p05"]
    ax = fig.add_subplot(1, 1, 1)
    ax.plot(t["freq"], t["cum_periodogram"], color=col("black"))
    ax.plot([0, 0.5], [0, 1], color=col("red"))
    ax.plot([0, 0.5], [b1, 1 + b1], ":", color=col("red"))
    ax.plot([0, 0.5], [-b1, 1 - b1], ":", color=col("red"))
    ax.plot([0, 0.5], [b2, 1 + b2], ":", color=col("black"))
    ax.plot([0, 0.5], [-b2, 1 - b2], ":", color=col("black"))
    tsx_xlim(ax, 0, 0.5)
    tsx_ylim(ax, min(np.nanmin(t["cum_periodogram"]), -b1),
                max(np.nanmax(t["cum_periodogram"]), 1 + b1))
    ax.set_xlabel("Frequency")
    ax.set_ylabel("Cumulative Power")
    ax.set_title("Series %s: Cumulative Periodogram (1%% red; 5%% black)" % x["series"])


def _spectrum_title(x):
    if x["call"]["smooth"] > 1:
        return "Smoothed Spectrum, Triangular window (%d)" % x["call"]["smooth"]
    return "Periodogram"


@text_method("vspectrum")
def tsx_text_vspectrum(x, digits=None):
    d = 4 if digits is None else digits
    if len(x["series"]) == 1:
        title = "Series %s: %s" % (x["series"][0], _spectrum_title(x))
    else:
        title = "Cross spectrum: %s - %s" % (x["series"][0], x["series"][1])
    return tsx_cat_block(title=title, table=tsx_format_table(x["table"], d))


def _log10(v):
    with np.errstate(divide="ignore", invalid="ignore"):
        return np.log10(np.asarray(v, dtype=float))


@plot_method("vspectrum")
def tsx_plot_vspectrum(x, fig):
    t = x["table"]
    xlog = x["call"]["xlog"]
    if len(x["series"]) == 1:
        ax = fig.add_subplot(1, 1, 1)
        fx = tsx_period_axis(ax, t["freq"], xlog[0])
        yv = _log10(t["spectrum"]) if xlog[1] else t["spectrum"]
        ax.plot(fx, yv, color=col("black"))
        ax.set_ylabel("Log10(Power)" if xlog[1] else "Power")
        ax.set_title("Series %s: %s" % (x["series"][0], _spectrum_title(x)))
        return
    s1, s2 = x["series"]
    ax1, ax3 = fig.subplots(2, 1)
    fx = tsx_period_axis(ax1, t["freq"], xlog[0])
    ax1.set_xlabel("")
    g1 = _log10(t["gain12"]) if xlog[1] else t["gain12"]
    g2 = _log10(t["gain21"]) if xlog[1] else t["gain21"]
    ax1.plot(fx, g1, color=col("black"))
    ax1.set_ylabel("log(Gains)" if xlog[1] else "Gains")
    ax1.set_title("Gains: %s <- %s (left - black) and %s <- %s (right - red)"
                  % (s2, s1, s1, s2), fontsize=9)
    ax2 = ax1.twinx()
    ax2.plot(fx, g2, color=col("red"))
    ax2.tick_params(axis="y", colors=col("red"))
    tsx_period_axis(ax3, t["freq"], xlog[0])
    ax3.plot(fx, t["coherence"], color=col("black"))
    tsx_ylim(ax3, 0, 1.1)
    ax3.set_ylabel("Coherence")
    title = "Squared Coherence: %s - %s" % (s1, s2)
    if x["call"]["smooth"] > 1:
        title += ". " + _spectrum_title(x)
    ax3.set_title(title, fontsize=9)
    fig.tight_layout()


@text_method("varspectrum")
def tsx_text_varspectrum(x, digits=None):
    d = 4 if digits is None else digits
    return tsx_cat_block(title="Series %s: AR Spectrum(%d)" % (x["series"], x["call"]["order"]),
                         table=tsx_format_table(x["table"], d,
                                                col_names=["Frequency", "Power"]))


@plot_method("varspectrum")
def tsx_plot_varspectrum(x, fig):
    t = x["table"]
    xlog = x["call"]["xlog"]
    ax = fig.add_subplot(1, 1, 1)
    fx = tsx_period_axis(ax, t["freq"], xlog[0])
    yv = _log10(t["spectrum"]) if xlog[1] else t["spectrum"]
    ax.plot(fx, yv, color=col("black"))
    ax.set_ylabel("Log10(Power)" if xlog[1] else "Power")
    ax.set_title("Series %s: AR Spectrum(%d)" % (x["series"], x["call"]["order"]))
