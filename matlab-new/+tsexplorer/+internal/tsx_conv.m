function out = tsx_conv(a, b)
%TSX_CONV Polynomial multiplication.
out = zeros(1, numel(a) + numel(b) - 1);
for i = 1:numel(a)
    idx = i:(i + numel(b) - 1);
    out(idx) = out(idx) + a(i) * b(:)';
end
end
