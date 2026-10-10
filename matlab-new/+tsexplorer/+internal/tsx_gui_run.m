function run = tsx_gui_run(y, names, tool, opts, series, nav)
%TSX_GUI_RUN Run a tool: returns the call made to the core (struct with the
%   tool and its arguments) and the result (or the MException).
spec = tsexplorer.internal.tsx_tool_spec(tool);
args = tsexplorer.internal.tsx_gui_args(tool, spec, opts, series, nav);
c = namedargs2cell(args);
try
    res = spec.fun(y, c{:}, names = names);
catch err
    res = err;
end
run = struct('call', struct('tool', string(tool), 'args', args), 'result', res);
end
