function r = tsx_fminsearch(fun, x0, tol_x, tol_fun, max_iter, max_fun_evals)
%TSX_FMINSEARCH Nelder-Mead simplex (Lagarias et al., 1998): initial simplex
%   with 5% perturbations (0.00025 for zero components), standard
%   coefficients and stopping rules on TOL_X and TOL_FUN. Same algorithm as
%   tsx_fminsearch() in R (and fminsearch with its default options).
%   Fields: par, value, iterations, fun_evals.
x0 = x0(:);
n = numel(x0);
if nargin < 3, tol_x = 1e-4; end
if nargin < 4, tol_fun = 1e-4; end
if nargin < 5, max_iter = 200 * n; end
if nargin < 6, max_fun_evals = 200 * n; end
rho = 1;
chi = 2;
psi = 0.5;
sigma = 0.5;
v = repmat(x0, 1, n + 1);
fv = zeros(1, n + 1);
fv(1) = fun(x0);
for j = 1:n
    y = x0;
    if y(j) ~= 0
        y(j) = 1.05 * y(j);
    else
        y(j) = 0.00025;
    end
    v(:, j + 1) = y;
    fv(j + 1) = fun(y);
end
[fv, ord] = sort(fv);
v = v(:, ord);
iter = 1;
nfev = n + 1;
while nfev < max_fun_evals && iter < max_iter
    if max(abs(fv(1) - fv(2:end))) <= max(tol_fun, 10 * eps * fv(1)) && ...
            max(max(abs(v(:, 2:end) - v(:, 1)))) <= max(tol_x, 10 * eps * max(v(:, 1)))
        break
    end
    xbar = mean(v(:, 1:n), 2);
    xr = (1 + rho) * xbar - rho * v(:, n + 1);
    fxr = fun(xr);
    nfev = nfev + 1;
    shrink = false;
    if fxr < fv(1)
        xe = (1 + rho * chi) * xbar - rho * chi * v(:, n + 1);
        fxe = fun(xe);
        nfev = nfev + 1;
        if fxe < fxr
            v(:, n + 1) = xe;
            fv(n + 1) = fxe;
        else
            v(:, n + 1) = xr;
            fv(n + 1) = fxr;
        end
    elseif fxr < fv(n)
        v(:, n + 1) = xr;
        fv(n + 1) = fxr;
    elseif fxr < fv(n + 1)
        xc = (1 + psi * rho) * xbar - psi * rho * v(:, n + 1);
        fxc = fun(xc);
        nfev = nfev + 1;
        if fxc <= fxr
            v(:, n + 1) = xc;
            fv(n + 1) = fxc;
        else
            shrink = true;
        end
    else
        xcc = (1 - psi) * xbar + psi * v(:, n + 1);
        fxcc = fun(xcc);
        nfev = nfev + 1;
        if fxcc < fv(n + 1)
            v(:, n + 1) = xcc;
            fv(n + 1) = fxcc;
        else
            shrink = true;
        end
    end
    if shrink
        for j = 2:(n + 1)
            v(:, j) = v(:, 1) + sigma * (v(:, j) - v(:, 1));
            fv(j) = fun(v(:, j));
        end
        nfev = nfev + n;
    end
    [fv, ord] = sort(fv);
    v = v(:, ord);
    iter = iter + 1;
end
r = struct('par', v(:, 1), 'value', fv(1), 'iterations', iter, 'fun_evals', nfev);
end
