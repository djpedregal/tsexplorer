function z = tsx_boxcox_shift(z)
%TSX_BOXCOX_SHIFT Shift a non positive series to make it positive.
mn = min(z, [], 'omitnan');
if mn <= 0
    z = z + abs(mn) + 1e-4;
end
end
