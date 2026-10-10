function v = tsx_values_matrix(x)
%TSX_VALUES_MATRIX Numeric matrix of the values of an input object (without
%   its dates). A vector is one column.
try
    v = tsexplorer.internal.tsx_input_parts(x);
catch
    error('tsexplorer:input', ...
        "All the columns of the forecasts and their standard deviations must be numeric.");
end
if ~isnumeric(v) && ~islogical(v)
    error('tsexplorer:input', ...
        "All the columns of the forecasts and their standard deviations must be numeric.");
end
if isvector(v)
    v = v(:);
end
v = double(v);
end
