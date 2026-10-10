function tsx_fgui_plot(p, fig)
%TSX_FGUI_PLOT Plot of toolforecast in the figure FIG: the plot of the
%   fplot result P, or a blank figure with the message of the error.
if isa(p, 'MException')
    clf(fig);
    ax = axes(fig, 'Visible', 'off');
    title(ax, p.message, 'Visible', 'on', 'FontSize', 9, 'Interpreter', 'none');
else
    tsexplorer.plot(p, figure = fig);
end
end
