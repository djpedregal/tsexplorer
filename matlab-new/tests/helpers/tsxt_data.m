function [y, names] = tsxt_data(name)
%TSXT_DATA Data used by the tests (as the helpers of the R tests):
%   "airpas", "scc", "nile", "lydia_pinkham" (the datasets), "la" =
%   log(airpas), "dla" = vdif(log(airpas), [1 1], [1 12]), "lp" =
%   log(lydia_pinkham), "dlp" = vdif(log(lydia_pinkham)). NAMES are the
%   names of the series of the dataset (the column names in R).
names = [];
switch name
    case "la"
        y = log(load_data("airpas"));
    case "dla"
        y = vdif(log(load_data("airpas")), [1 1], [1 12]);
    case "lp"
        y = log(load_data("lydia_pinkham"));
    case "dlp"
        y = vdif(log(load_data("lydia_pinkham")));
    otherwise
        [y, names] = load_data(name);
end
end
