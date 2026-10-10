function [tpos, gpos] = tsx_ui_place(offset)
%TSX_UI_PLACE Positions ([left bottom width height], pixels) of the text
%   window, in the top left corner of the screen, and of the graphics window,
%   to its right, so that both are side by side without overlapping (as
%   tsx_tk_place in R). OFFSET (pixels) moves both down and right (the
%   windows of toolforecast are shifted with respect to those of tooltest).
if nargin < 1
    offset = 0;
end
scr = get(groot, 'ScreenSize');
sw = scr(3);
sh = scr(4);
margin = 10;
border = 20;   % window borders (pixels)
title = 60;    % title bar, menus and task bar (pixels)
w = min(820, floor(sw / 2) - margin - border);
h = min(640, sh - 2 * margin - 2 * title - offset);
top = sh - margin - title - offset;
tpos = [margin + offset, top - h, w, h];
x = margin + offset + w + border + margin;
gw = max(300, min(900, sw - x - margin - border));
gh = max(300, min(680, sh - 2 * margin - 2 * title - offset));
gpos = [x, top - gh, gw, gh];
end
