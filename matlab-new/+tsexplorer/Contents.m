% tsexplorer: functions of tsexplorer called by their full names
%
% plot, print and fplot are in this package so that they do not hide the
% functions of MATLAB with the same names. adftest is here too, so that
% tooltest runs it even when another function adftest (e.g. that of the
% Econometrics Toolbox) comes first on the path; the function adftest of
% the folder calls it. The rest of the functions (vident, tooltest,
% toolforecast, ...) are called by their names; see the file Contents.m of
% the folder that contains +tsexplorer.
%
%   tsexplorer.print    - Text output of a result of the package.
%   tsexplorer.plot     - Plot of a result of the package.
%   tsexplorer.fplot    - Plot of actual values and forecasts.
%   tsexplorer.adftest  - Augmented Dickey-Fuller unit root tests.
