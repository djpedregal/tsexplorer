function opts = tsx_gui_set_option(opts, links, tool, name, value)
%TSX_GUI_SET_OPTION Set an option of a tool and propagate it to the linked
%   options (LINKS, the second output of tooltest_defaults).
opts.(tool).(name) = value;
groups = struct2cell(links);
for g = 1:numel(groups)
    mems = groups{g};
    hit = any(cellfun(@(mm) mm(1) == tool && mm(2) == name, mems));
    if hit
        for k = 1:numel(mems)
            mm = mems{k};
            opts.(mm(1)).(mm(2)) = value;
        end
    end
end
end
