function level = tsx_check_level(level)
%TSX_CHECK_LEVEL Check the confidence level of the prediction intervals.
if ~isnumeric(level) || numel(level) ~= 1 || isnan(level) || level <= 0 || level >= 1
    error('tsexplorer:level', "'level' must be a number between 0 and 1.");
end
end
