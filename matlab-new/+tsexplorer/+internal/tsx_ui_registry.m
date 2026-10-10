function out = tsx_ui_registry(action, kind, app)
%TSX_UI_REGISTRY Open windows of the interfaces (tsx_tk_windows in R): at
%   most one text window and one graphics window for each kind ("tooltest",
%   "toolforecast"), so that a new call reuses them.
%     tsx_ui_registry("get", KIND)          app of the open window or []
%     tsx_ui_registry("set", KIND, APP)     register APP
%     tsx_ui_registry("remove", KIND, FIG)  unregister if its window is FIG
persistent reg
if isempty(reg)
    reg = struct();
end
out = [];
kind = char(kind);
switch action
    case "get"
        if isfield(reg, kind) && isvalid(reg.(kind).fig)
            out = reg.(kind);
        end
    case "set"
        reg.(kind) = app;
    case "remove"
        if isfield(reg, kind) && isequal(reg.(kind).fig, app)
            reg = rmfield(reg, kind);
        end
end
end
