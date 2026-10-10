function out = tsx_with_seed(seed, fun)
%TSX_WITH_SEED Evaluate FUN() with a given seed, restoring the state of the
%   random number generator afterwards (no change if SEED is empty).
if isempty(seed)
    out = fun();
    return
end
old = rng();
cleanup = onCleanup(@() rng(old));
rng(seed);
out = fun();
end
