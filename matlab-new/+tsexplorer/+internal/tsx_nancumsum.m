function out = tsx_nancumsum(x)
%TSX_NANCUMSUM Cumulative sum skipping missing values (kept as NaN).
out = nan(size(x));
ok = ~isnan(x);
out(ok) = cumsum(x(ok));
end
