function d = tsxt_ref_dir()
%TSXT_REF_DIR Folder of the shared reference files (r/inst/extdata/reference).
here = fileparts(mfilename('fullpath'));
d = fullfile(here, '..', '..', '..', 'r', 'inst', 'extdata', 'reference');
end
