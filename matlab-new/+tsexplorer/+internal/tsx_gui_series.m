function sel = tsx_gui_series(mode, s1, s2, all)
%TSX_GUI_SERIES Series selection given the selection mode of a tool: S1, S2
%   are indices ([] for S2 when not given), ALL = true selects "all" when the
%   mode allows it. Returns [] (no selection), an index, two indices or
%   "all".
if nargin < 2 || isempty(s1), s1 = 1; end
if nargin < 3, s2 = []; end
if nargin < 4, all = false; end
switch mode
    case "none"
        sel = [];
    case "single"
        sel = s1;
    case {"single_all", "var"}
        if all
            sel = "all";
        else
            sel = s1;
        end
    case "pair"
        if isempty(s2)
            s2 = s1;
        end
        if s1 == s2
            sel = s1;
        else
            sel = [s1, s2];
        end
    case "pair_all"
        if all
            sel = "all";
        else
            if isempty(s2)
                s2 = 2;
            end
            sel = [s1, s2];
        end
end
end
