function out = tsx_text_gausstest(x, digits)
%TSX_TEXT_GAUSSTEST Text output of gausstest (print.tsx_gausstest in R).
import tsexplorer.internal.*
if isempty(digits)
    digits = x.call.digits;
end
t = x.table;
lines = tsx_format_table(t(:, {'skewness', 'kurtosis', 'bj', 'p_bj', 'ksl', 'p_ksl'}), digits, ...
    x.series, ["Skewness", "Kurtosis(-3)", "Bera-Jarque", "P-value", "KSLilliefors", "P-value"]);
out = tsx_cat_block("Bera-Jarque and Kolmogorov-Smirnov Lilliefors (KSL) gaussianity tests.", ...
    ["H0: Distribution is gaussian."; "(Assumptions: Independence)"; ...
     "(Approximate P-value for KSL test)."], lines);
if ~isempty(x.bj_multi)
    out = [out; ""; tsx_cat_block([], [], tsx_format_table({x.bj_multi, x.p_bj_multi}, digits, ...
        [], ["Multivariate Bera-Jarque", "P-value"]))];
end
end
