function v = tsx_tri_interp(px, py, pv, tri, x0, y0)
%TSX_TRI_INTERP Linear interpolation on a triangulation: value at (X0, Y0)
%   from the barycentric coordinates of the containing triangle; NaN outside
%   the convex hull.
for k = 1:size(tri, 1)
    i = tri(k, :);
    x1 = px(i(1)); y1 = py(i(1));
    x2 = px(i(2)); y2 = py(i(2));
    x3 = px(i(3)); y3 = py(i(3));
    den = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3);
    w1 = ((y2 - y3) * (x0 - x3) + (x3 - x2) * (y0 - y3)) / den;
    w2 = ((y3 - y1) * (x0 - x3) + (x1 - x3) * (y0 - y3)) / den;
    w3 = 1 - w1 - w2;
    tol = -1e-10;
    if w1 >= tol && w2 >= tol && w3 >= tol
        v = w1 * pv(i(1)) + w2 * pv(i(2)) + w3 * pv(i(3));
        return
    end
end
v = NaN;
end
