function x = tsxt_ref_input(file)
%TSXT_REF_INPUT Shared simulated input data (reference/inputs/<file>).
x = readmatrix(fullfile(tsxt_ref_dir(), 'inputs', file), ...
    'TreatAsMissing', {'NA', 'NaN'}, 'NumHeaderLines', 1);
end
