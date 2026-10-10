function c = tsx_rcolor(name)
%TSX_RCOLOR RGB triplet of the R colours used by the plots of the package.
switch string(name)
    case "black",          c = [0 0 0];
    case "red",            c = [1 0 0];
    case "blue",           c = [0 0 1];
    case "darkgreen",      c = [0 0.392 0];
    case "magenta3",       c = [0.804 0 0.804];
    case "gold3",          c = [0.804 0.678 0];
    case "cyan3",          c = [0 0.804 0.804];
    case "green3",         c = [0 0.804 0];
    case "lightsteelblue", c = [0.690 0.769 0.871];
    case "navy",           c = [0 0 0.502];
    otherwise
        error('tsexplorer:color', "Unknown colour %s.", name);
end
end
