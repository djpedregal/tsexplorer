function tsx_gui_plot(result, tool, series, fig)
%TSX_GUI_PLOT Plot the result of a tool in the figure FIG (a blank figure
%   with the message for errors and tools without plot).
spec = tsexplorer.internal.tsx_tool_spec(tool);
if isa(result, 'MException') || ~spec.plot
    clf(fig);
    if isa(result, 'MException')
        ax = axes(fig, 'Visible', 'off');
        title(ax, result.message, 'Visible', 'on', 'FontSize', 9, 'Interpreter', 'none');
    end
    return
end
if spec.series_in_plot
    tsexplorer.plot(result, series = series, figure = fig);
else
    tsexplorer.plot(result, figure = fig);
end
end
