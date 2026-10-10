function d = tsx_ui_options_dialog(parent, title, options, current, apply, visible)
%TSX_UI_OPTIONS_DIALOG Options dialog: one row per option; on OK the values
%   (struct) are passed to APPLY, which parses them with
%   tsx_gui_parse_option; its errors are shown in an alert and the dialog
%   stays open. Returns the dialog ([] when the tool has no options).
import tsexplorer.internal.*
if nargin < 6
    visible = true;
end
d = [];
if isempty(options)
    if visible
        uialert(parent, "No options for this tool.", title, 'Icon', 'info');
    end
    return
end
n = numel(options);
h = 40 * n + 70;
pp = parent.Position;
d = uifigure('Name', title, 'Position', [pp(1) + 40, pp(2) + pp(4) - h - 60, 560, h], ...
    'WindowStyle', 'modal', 'Visible', matlab.lang.OnOffSwitchState(visible));
g = uigridlayout(d, [n + 1, 2]);
g.ColumnWidth = {'1x', 230};
g.RowHeight = [repmat({30}, 1, n), {36}];
getters = struct();
for k = 1:n
    op = options(k);
    val = current.(op.name);
    uilabel(g, 'Text', op.label);
    switch op.type
        case "logical"
            c = uicheckbox(g, 'Text', '', 'Value', logical(val));
            getters.(op.name) = @() c.Value;
        case "logical2"
            val = logical(val(:)');
            val = val(mod(0:1, numel(val)) + 1);
            gg = uigridlayout(g, [1 2]);
            gg.Padding = [0 0 0 0];
            c1 = uicheckbox(gg, 'Text', 'Period', 'Value', val(1));
            c2 = uicheckbox(gg, 'Text', 'Power', 'Value', val(2));
            getters.(op.name) = @() [c1.Value, c2.Value];
        case "select"
            c = uidropdown(g, 'Items', op.choice_labels, 'ItemsData', op.choice_values);
            if ismember(val, op.choice_values)
                c.Value = val;
            end
            getters.(op.name) = @() c.Value;
        otherwise
            c = uieditfield(g, 'text', 'Value', tsx_gui_option_text(op, val));
            getters.(op.name) = @() c.Value;
    end
end
bg = uigridlayout(g, [1 2]);
bg.Padding = [0 0 0 0];
bg.Layout.Column = [1 2];
uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) ok());
uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(d));

    function ok()
        values = structfun(@(gt) gt(), getters, 'UniformOutput', false);
        try
            apply(values);
            delete(d);
        catch e
            uialert(d, e.message, title);
        end
    end
end
