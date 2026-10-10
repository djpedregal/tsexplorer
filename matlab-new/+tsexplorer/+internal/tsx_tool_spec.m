function spec = tsx_tool_spec(id)
%TSX_TOOL_SPEC Entry of the tool ID in the registry tsx_tools().
tools = tsexplorer.internal.tsx_tools();
spec = tools([tools.id] == string(id));
if isempty(spec)
    error('tsexplorer:tool', "Unknown tool: %s", id);
end
end
