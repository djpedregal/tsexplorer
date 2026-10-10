function tools = tsx_tools_for(m)
%TSX_TOOLS_FOR Tools of the Tests menu available for M series (the tools
%   needing several series are removed when m = 1).
tools = tsexplorer.internal.tsx_tools();
if m == 1
    tools = tools(~[tools.multi]);
end
end
