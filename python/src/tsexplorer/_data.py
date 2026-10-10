# Example datasets of the package (data/ in the R version), read from the
# CSV files in data/csv (copies of r/inst/extdata/csv).

import os

import numpy as np
import pandas as pd

_DIR = os.path.join(os.path.dirname(__file__), "data", "csv")

DATASETS = ("airpas", "nile", "victims", "usgdp", "steel", "lydia_pinkham", "furnace",
            "gaselec", "unemployment", "electricity", "scc")


def load_data(name):
    """Example datasets of the package.

    Parameters
    ----------
    name : str
        Name of the dataset:

        * ``"airpas"``: Airline passengers. Monthly totals of international
          airline passengers (thousands), January 1949 to December 1960 (144
          observations). Series G of Box and Jenkins. Source: Box, G.E.P.,
          Jenkins, G.M. and Reinsel, G.C. (2008). *Time Series Analysis,
          Forecasting and Control*. Wiley.
        * ``"nile"``: Nile river flow. Annual flow of the river Nile at
          Aswan, 1871-1970 (100 observations). Source: Cobb, G.W. (1978). The
          problem of the Nile: conditional solution to a changepoint problem.
          *Biometrika*, 65, 243-251.
        * ``"victims"``: Road casualties. Monthly number of car drivers killed
          or seriously injured in Great Britain, January 1969 to December
          1984 (192 observations). Source: Harvey, A.C. and Durbin, J. (1986).
          The effects of seat belt legislation on British road casualties: a
          case study in structural time series modelling. *Journal of the
          Royal Statistical Society A*, 149, 187-227.
        * ``"usgdp"``: US GDP. US gross domestic product, quarterly data (241
          observations, without dates).
        * ``"steel"``: Steel data. Example series (157 observations, without
          dates).
        * ``"lydia_pinkham"``: Lydia Pinkham advertising and sales. Annual
          advertising expenditure and sales of the Lydia E. Pinkham Medicine
          Company, 1907-1960 (54 observations of ``advertising`` and
          ``sales``). Source: Palda, K.S. (1964). *The Measurement of
          Cumulative Advertising Effects*. Prentice-Hall.
        * ``"furnace"``: Gas furnace data. Box-Jenkins series J: output CO2
          concentration and input gas rate of a gas furnace, sampled every 9
          seconds (296 observations of ``co2`` and ``gas_rate``, without
          dates). Source: Box, G.E.P., Jenkins, G.M. and Reinsel, G.C.
          (2008). *Time Series Analysis, Forecasting and Control*. Wiley.
        * ``"gaselec"``: Gas and electricity data. Two monthly series from
          January 1992 (213 observations of ``y1`` and ``y2``).
        * ``"unemployment"``: Unemployment data. Two monthly series from
          January 2000 (124 observations of ``y1`` and ``y2``).
        * ``"electricity"``: Electricity data. Two high frequency series (2472
          observations of ``y1`` and ``y2``, without dates).
        * ``"scc"``: SCC data. Three series (62 observations of ``y1``,
          ``y2`` and ``y3``, without dates).

    Returns
    -------
    pandas.Series or pandas.DataFrame
        A ``Series`` without name for the datasets of one series and a
        ``DataFrame`` with the names of the series as columns for the others
        (as the ``ts`` and matrix objects of the R version). The datasets with
        a calendar are indexed by a ``PeriodIndex`` (annual or monthly), the
        others by a ``RangeIndex``.

    See Also
    --------
    as_tsx_matrix

    Examples
    --------
    >>> airpas = load_data("airpas")
    >>> plotband(airpas)
    >>> load_data("lydia_pinkham").head()
    """
    if name not in DATASETS:
        raise ValueError("Unknown dataset: %s." % name)
    t = pd.read_csv(os.path.join(_DIR, name + ".csv"), na_values=["NA", "NaN"])
    index = None
    if t.columns[0] == "time":
        time = t["time"].to_numpy(dtype=float)
        freq = int(round(1 / np.median(np.diff(time))))
        k = np.round(time * freq).astype(int)
        year = k // freq
        month = (k % freq) * (12 // freq) + 1
        pfreq = {1: "Y", 4: "Q", 12: "M"}[freq]
        index = pd.PeriodIndex([pd.Period(year=int(a), month=int(b), freq=pfreq)
                                for a, b in zip(year, month)])
        t = t.drop(columns="time")
    if index is None:
        index = pd.RangeIndex(len(t))
    t.index = index
    t.columns = [str(c) for c in t.columns]
    if t.shape[1] == 1:
        s = t.iloc[:, 0].astype(float)
        s.name = None
        return s
    return t.astype(float)
