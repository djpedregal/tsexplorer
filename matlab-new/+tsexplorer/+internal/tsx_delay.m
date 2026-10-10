function out = tsx_delay(y, lags)
%TSX_DELAY Matrix of lagged variables.
%   Rows are t = maxlag+1, ..., T; block i holds y lagged lags(i) periods.
if isvector(y)
    y = y(:);
end
n = size(y, 1);
m = size(y, 2);
maxlag = max(lags);
out = zeros(n - maxlag, m * numel(lags));
for i = 1:numel(lags)
    out(:, ((i - 1) * m + 1):(i * m)) = y((maxlag - lags(i) + 1):(n - lags(i)), :);
end
end
