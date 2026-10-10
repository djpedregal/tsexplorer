function [y, names, dates] = load_data(name)
%LOAD_DATA Example datasets of the package.
%   [Y, NAMES, DATES] = load_data(NAME)
%
%   Arguments:
%     NAME     Name of the dataset:
%       "airpas"         Airline passengers. Monthly totals of
%                        international airline passengers (thousands),
%                        January 1949 to December 1960 (144 observations).
%                        Series G of Box and Jenkins. Source: Box, G.E.P.,
%                        Jenkins, G.M. and Reinsel, G.C. (2008). Time
%                        Series Analysis, Forecasting and Control. Wiley.
%       "nile"           Nile river flow. Annual flow of the river Nile at
%                        Aswan, 1871-1970 (100 observations). Source: Cobb,
%                        G.W. (1978). The problem of the Nile: conditional
%                        solution to a changepoint problem. Biometrika, 65,
%                        243-251.
%       "victims"        Road casualties. Monthly number of car drivers
%                        killed or seriously injured in Great Britain,
%                        January 1969 to December 1984 (192 observations).
%                        Source: Harvey, A.C. and Durbin, J. (1986). The
%                        effects of seat belt legislation on British road
%                        casualties: a case study in structural time series
%                        modelling. Journal of the Royal Statistical
%                        Society A, 149, 187-227.
%       "usgdp"          US GDP. US gross domestic product, quarterly data
%                        (241 observations, without dates).
%       "steel"          Steel data. Example series (157 observations,
%                        without dates).
%       "lydia_pinkham"  Lydia Pinkham advertising and sales. Annual
%                        advertising expenditure and sales of the Lydia E.
%                        Pinkham Medicine Company, 1907-1960 (54
%                        observations of advertising and sales). Source:
%                        Palda, K.S. (1964). The Measurement of Cumulative
%                        Advertising Effects. Prentice-Hall.
%       "furnace"        Gas furnace data. Box-Jenkins series J: output CO2
%                        concentration and input gas rate of a gas furnace,
%                        sampled every 9 seconds (296 observations of
%                        co2 and gas_rate, without dates). Source: Box,
%                        G.E.P., Jenkins, G.M. and Reinsel, G.C. (2008).
%                        Time Series Analysis, Forecasting and Control.
%                        Wiley.
%       "gaselec"        Gas and electricity data. Two monthly series from
%                        January 1992 (213 observations of y1 and y2).
%       "unemployment"   Unemployment data. Two monthly series from January
%                        2000 (124 observations of y1 and y2).
%       "electricity"    Electricity data. Two high frequency series (2472
%                        observations of y1 and y2, without dates).
%       "scc"            SCC data. Three series (62 observations of y1, y2
%                        and y3, without dates).
%
%   Value:
%     Y        Numeric matrix (rows are time, columns are series).
%     NAMES    Names of the series (string row vector).
%     DATES    Dates of the rows (datetime column vector: first day of each
%              year or month) for the datasets with a calendar, [] for the
%              others.
%
%   The data are read from the CSV files of the folder data/csv.
%
%   Examples:
%     [y, names, d] = load_data("airpas");
%     tsexplorer.plot(plotband(timetable(d, y)))
%     [lp, names] = load_data("lydia_pinkham")
%
%   See also as_tsx_matrix.
arguments
    name (1, 1) string
end
root = fileparts(mfilename('fullpath'));
file = fullfile(root, 'data', 'csv', name + ".csv");
if ~isfile(file)
    error('tsexplorer:data', "Unknown dataset: %s.", name);
end
t = readtable(file, 'Delimiter', ',', 'TreatAsMissing', {'NaN', 'NA'});
names = string(t.Properties.VariableNames);
dates = [];
if names(1) == "time"
    time = t.time;
    freq = round(1 / median(diff(time)));
    k = round(time * freq);
    year = floor(k / freq);
    month = mod(k, freq) * (12 / freq) + 1;
    dates = datetime(year, month, 1);
    t.time = [];
    names = names(2:end);
end
y = t{:, :};
end
