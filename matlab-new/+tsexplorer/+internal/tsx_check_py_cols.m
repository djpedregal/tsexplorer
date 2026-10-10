function tsx_check_py_cols(mh, m)
%TSX_CHECK_PY_COLS The number of columns of py must be a multiple of m.
if mod(mh, m) ~= 0
    error('tsexplorer:py', ...
        "The number of columns of 'py' must be a multiple of the number of series.");
end
end
