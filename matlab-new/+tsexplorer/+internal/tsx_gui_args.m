function args = tsx_gui_args(tool, spec, opts, series, nav)
%TSX_GUI_ARGS Arguments (struct) of the call to the core function of a
%   tool: its options, the selected series and the navigation values.
args = opts.(tool);
if spec.series_in_plot
    % vident2: the pair of series is an argument of the plot
elseif spec.series ~= "none"
    args.series = series;
end
if spec.nav == "subsample"
    args.subsample = nav.subsample;
    args.overlay = nav.overlay;
end
if spec.nav == "highlight"
    args.highlight = nav.highlight;
end
end
