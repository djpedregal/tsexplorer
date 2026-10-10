function [y, names, dates, index] = as_tsx_matrix(y, opts)
%AS_TSX_MATRIX Convert input data to the matrix format used by tsexplorer.
%   Every function of the package accepts data without dates (numeric
%   vector or matrix, or a table of numeric columns) or with dates
%   (timetable, or table with one datetime column) and converts it with
%   this function into a numeric T x m matrix (rows are time, columns are
%   series) with the names of the series.
%
%   [Y, NAMES, DATES, INDEX] = as_tsx_matrix(Y)
%   [...] = as_tsx_matrix(Y, names=[], trim=true)
%
%   Arguments:
%     Y       Numeric vector or matrix, timetable, or table (numeric
%             columns and, optionally, one datetime column).
%     names   Optional names of the series (string array). If shorter than
%             the number of series, the remaining ones take the default
%             names "#1", "#2", ... A single string with blank-separated
%             names is also accepted.
%     trim    If true (default), rows at the beginning and at the end of
%             the sample where all the series are missing are removed.
%
%   Details:
%     The dates, when available, are returned in DATES (one per row) and
%     are used in the time axes of the plots and in the tables of the
%     forecasting tools. They are the row times of a timetable or the
%     datetime column of a table. Dates must be increasing and without
%     repetitions.
%
%   Value:
%     Y       Numeric T x m matrix.
%     NAMES   Names of the series (string row vector): the variable names
%             of the table, the argument names or "#1", "#2", ...
%     DATES   Dates of the rows (datetime column vector), [] for inputs
%             without dates.
%     INDEX   Rows of the input retained by trim ([] if none was removed).
%
%   Examples:
%     y = load_data("airpas");
%     as_tsx_matrix(y(1:3))
%     [z, nm] = as_tsx_matrix([1 NaN; 2 2; 3 3; 4 4; 5 5], names="a b")
%     d = datetime(2024, 1, 1) + caldays(0:4)';
%     [~, ~, dates] = as_tsx_matrix(timetable(d, [3; 1; 4; 1; 5]))
%
%   See also load_data.
arguments
    y
    opts.names = []
    opts.trim (1, 1) logical = true
end
import tsexplorer.internal.*
[values, cn, dates] = tsx_input_parts(y);
if isempty(values)
    error('tsexplorer:input', "'y' is empty.");
end
if ~isnumeric(values) && ~islogical(values)
    error('tsexplorer:input', "'y' must be numeric (vector, matrix, table or timetable).");
end
if ndims(values) > 2
    error('tsexplorer:input', "'y' must have at most two dimensions.");
end
if isvector(values)
    values = values(:);
end
y = double(values);
m = size(y, 2);
if isempty(opts.names)
    names = tsx_names(m, cn);
else
    names = tsx_names(m, opts.names);
end
if ~isempty(dates) && numel(dates) ~= size(y, 1)
    error('tsexplorer:input', "The number of dates and of observations of 'y' differ.");
end
index = [];
if opts.trim
    [y, index] = tsx_remove_nan(y);
    if ~isempty(dates) && ~isempty(index)
        dates = dates(index);
    end
end
if size(y, 1) == 0
    error('tsexplorer:input', "'y' contains only missing values.");
end
end
