function lines = print(r, opts)
%PRINT Text output of a result of the package.
%   Writes in the Command Window the tables of a result of the package:
%   titles, null hypotheses, legends of the abbreviations and the tables
%   with the significance marks. It is the text shown by tooltest
%   and toolforecast.
%
%   tsexplorer.print(R)
%   tsexplorer.print(R, digits=D)
%   LINES = tsexplorer.print(...)
%
%   Arguments:
%     R        A result of a function of the package (a struct whose field
%              class is ["tsx_<function>" "tsx_result"]).
%     digits   Number of decimals (default: that of each class, 4 in most
%              of them; for sumstats and gausstest, their option digits).
%
%   Value:
%     With an output argument, the lines (string column vector) are
%     returned without writing them.
%
%   Details:
%     Each class has its own method, tsexplorer.internal.tsx_text_<class>;
%     results without one show their fields.
%
%   Examples:
%     y = load_data("airpas");
%     r = adftest(log(y), lags=1:4);
%     tsexplorer.print(r)
%     lines = tsexplorer.print(r, digits=3);
%
%   See also tsexplorer.plot.
arguments
    r struct
    opts.digits = []
end
name = extractAfter(r.class(1), "tsx_");
fun = "tsexplorer.internal.tsx_text_" + name;
if ~isempty(which(fun))
    out = feval(fun, r, opts.digits);
else
    out = tsexplorer.internal.tsx_text_result(r);
end
if nargout > 0
    lines = out;
else
    fprintf('%s\n', out);
end
end
