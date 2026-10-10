function s = tsx_format_num(x)
%TSX_FORMAT_NUM Number as format() of R: up to 7 significant digits without
%   trailing zeros (e.g. 1.5, 0.95, 1.234568).
s = string(sprintf('%.7g', x));
end
