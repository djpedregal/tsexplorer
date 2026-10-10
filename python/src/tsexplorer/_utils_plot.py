# Plot helpers used by the plot methods (base graphics of R translated to
# matplotlib). Every plot method draws in a matplotlib Figure given by
# TsxResult.plot().

import colorsys

import numpy as np
import pandas as pd

# Colours of R used by the plots.
COLORS = {"black": "#000000", "red": "#FF0000", "blue": "#0000FF", "green3": "#00CD00",
          "darkgreen": "#006400", "lightsteelblue": "#B0C4DE", "navy": "#000080",
          "magenta3": "#CD00CD", "gold3": "#CDAD00", "cyan3": "#00CDCD"}


def col(name):
    return COLORS.get(name, name)


def _rlim(lims):
    lo, hi = lims
    pad = (hi - lo) * 0.04
    return lo - pad, hi + pad


def tsx_xlim(ax, *lims):
    """Limits of the horizontal axis with the margin of 4% of R (xaxs =
    "r")."""
    ax.set_xlim(*_rlim(lims[0] if len(lims) == 1 else lims))


def tsx_ylim(ax, *lims):
    """Limits of the vertical axis with the margin of 4% of R (yaxs =
    "r")."""
    ax.set_ylim(*_rlim(lims[0] if len(lims) == 1 else lims))


def tsx_abline(ax, a, b, x, **kwargs):
    """abline(a, b) of R: line of intercept a and slope b, anchored at the
    mean of the data x (so that it does not change the limits of the
    axes)."""
    x0 = float(np.nanmean(np.asarray(x, dtype=float)))
    ax.axline((x0, a + b * x0), slope=b, **kwargs)


def tsx_rainbow(n):
    """rainbow(n) of R."""
    return [colorsys.hsv_to_rgb(k / n, 1, 1) for k in range(n)]


def tsx_dark3(n):
    """Qualitative colours for several series (hcl.colors(n, "Dark 3") in
    R)."""
    base = ["#E16A86", "#50A315", "#009ADE", "#B88A00", "#00AD9A", "#C86DD7", "#6F92E5",
            "#D2785D"]
    if n <= len(base):
        idx = np.round(np.linspace(0, len(base) - 1, n)).astype(int) if n > 1 else [0]
        return [base[i] for i in idx]
    return [colorsys.hsv_to_rgb(k / n, 0.7, 0.75) for k in range(n)]


def tsx_time_coords(dates, t):
    """Horizontal axis of the time plots. ``dates`` are the dates of the
    plotted rows (or None) and ``t`` their row numbers (from 1). Returns the
    coordinates x, the limits xlim (one period of margin) and the axis
    label."""
    t = np.asarray(t)
    if dates is None:
        return {"x": t, "xlim": (t[0] - 1, t[-1] + 1), "lab": "Samples"}
    x = pd.DatetimeIndex(dates)
    dx = (x[1:] - x[:-1]).min() if len(x) > 1 else pd.Timedelta(days=1)
    return {"x": x, "xlim": (x[0] - dx, x[-1] + dx), "lab": "Time"}


def tsx_plot_correlogram(fig, lags, values, se, s, titles):
    """Correlogram bars with 2 standard error bands, seasonal lags drawn in
    red dotted lines."""
    lags = np.asarray(lags)
    k = values.shape[1]
    axes = fig.subplots(k, 1, squeeze=False)[:, 0]
    for j, ax in enumerate(axes):
        v = values[:, j]
        band = 2 * se[:, j]
        lo = np.nanmin(np.r_[v, band, -band]) - 0.05
        hi = np.nanmax(np.r_[v, band, -band]) + 0.05
        seas = (lags % s) == 0
        if (~seas).any():
            ax.vlines(lags[~seas], 0, v[~seas], colors=col("blue"))
        if seas.any():
            ax.vlines(lags[seas], 0, v[seas], colors=col("red"), linestyles=":")
        ax.axhline(0, color=col("blue"), linewidth=0.8)
        ax.plot(lags, band, ":", color=col("red"))
        ax.plot(lags, -band, ":", color=col("red"))
        tsx_xlim(ax, lags.min() - 1, lags.max() + 1)
        tsx_ylim(ax, lo, hi)
        ax.set_ylabel("Correlation")
        if j == k - 1:
            ax.set_xlabel("Lags")
        ax.set_title(titles[j], fontsize=9)
    fig.tight_layout()
    return axes


def tsx_period_axis(ax, w, logx):
    """Frequency axis labelled with periods. Returns the x coordinates and
    sets the limits, ticks and label of the axis."""
    w = np.asarray(w, dtype=float)
    periods = np.array([12, 6, 4, 3, 2.4, 2])
    labels = ["12", "6", "4", "3", "2.4", "2"]
    if not logx:
        tsx_xlim(ax, 0, np.pi)
        ax.set_xticks(np.r_[0, 2 * np.pi / periods])
        ax.set_xticklabels(["Inf"] + labels)
        ax.set_xlabel("Period")
        return w
    with np.errstate(divide="ignore"):
        lw = np.log10(w)
    lw[w == 0] = np.nan
    tsx_xlim(ax, np.nanmin(lw), np.log10(np.pi))
    ax.set_xticks(np.log10(2 * np.pi / periods))
    ax.set_xticklabels(labels)
    ax.set_xlabel("Log10(Period)")
    return lw


def tsx_hist_plot(ax, d, axes=True):
    """Histogram (bars) with the normal (red) and kernel (green) densities
    of tsx_hist_data()."""
    hh = d["hist"]
    dd = d["density"]
    ax.bar(hh["lower"], hh["count"], width=hh["upper"] - hh["lower"], align="edge",
           color=col("lightsteelblue"), edgecolor=col("navy"))
    ax.plot(dd["x"], dd["normal"], color=col("red"), linewidth=2)
    ax.plot(dd["x"], dd["kernel"], color=col("green3"), linewidth=2)
    tsx_xlim(ax, min(hh["lower"].min(), hh["upper"].min()), max(hh["lower"].max(),
                                                               hh["upper"].max()))
    tsx_ylim(ax, 0, max(hh["count"].max(), dd["normal"].max(), dd["kernel"].max()))
    if not axes:
        ax.set_xticks([])
        ax.set_yticks([])
