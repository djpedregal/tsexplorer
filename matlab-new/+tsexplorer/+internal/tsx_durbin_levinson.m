function spacf = tsx_durbin_levinson(r)
%TSX_DURBIN_LEVINSON Partial autocorrelations from autocorrelations.
r = r(:);
nc = numel(r);
spacf = r;
fi = zeros(nc, 1);
fi(1) = r(1);
for i = 1:(nc - 1)
    fi(i + 1) = (r(i + 1) - sum(fi(1:i) .* flipud(r(1:i)))) / (1 - sum(fi .* r));
    spacf(i + 1) = fi(i + 1);
    fi(1:i) = fi(1:i) - fi(i + 1) * flipud(fi(1:i));
end
end
