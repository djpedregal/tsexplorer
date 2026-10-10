function s = tsxt_ref(name)
%TSXT_REF Stored reference results
%   (r/inst/extdata/reference/<name>.json, shared with the R and Python
%   versions).
s = jsondecode(fileread(fullfile(tsxt_ref_dir(), name + ".json")));
end
