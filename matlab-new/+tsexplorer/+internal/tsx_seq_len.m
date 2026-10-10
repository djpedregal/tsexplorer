function x = tsx_seq_len(from, to, n)
%TSX_SEQ_LEN N equally spaced values from FROM to TO, computed as
%   seq(from, to, length.out = n) in R: [from, from + (1:n-2) * by, to].
if n == 1
    x = from;
    return
end
by = (to - from) / (n - 1);
x = [from, from + (1:(n - 2)) * by, to];
end
