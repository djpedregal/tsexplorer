function tab = tsx_compare_losses(loss, trunc, nofs)
%TSX_COMPARE_LOSSES Diebold-Mariano, sign and Wilcoxon tests for every pair
%   of forecasts and every loss: LOSS is a struct of matrices (periods x
%   forecasts), one field per loss.
import tsexplorer.internal.*
ln = string(fieldnames(loss))';
nf = size(loss.(ln(1)), 2);
tab = table();
for i = 1:(nf - 1)
    for j = (i + 1):nf
        for l = ln
            li = loss.(l)(:, i);
            lj = loss.(l)(:, j);
            dm = tsx_dm_test(li - lj, trunc, nofs);
            sg = tsx_sign_test(li - lj, nofs);
            wi = tsx_signrank(li, lj);
            tab = [tab; table(i, j, l, dm(1), dm(2), sg(1), sg(2), wi(1), wi(2), ...
                'VariableNames', {'f1', 'f2', 'loss', 'dm', 'p_dm', 'sign', 'p_sign', ...
                                  'wilcoxon', 'p_wilcoxon'})]; %#ok<AGROW>
        end
    end
end
end
