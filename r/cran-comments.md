## Submission

This is a new submission.

## Test environments

* Local: Windows 11, R 4.6.1
* GitHub Actions: Windows, macOS and Ubuntu (R release), Ubuntu (R devel)
* win-builder: R devel and R release

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  New submission.

## Notes for the reviewers

* The graphical interfaces `tooltest()` and `toolforecast()` open windows
  ('Tcl/Tk', or a 'shiny' application), so their examples are wrapped in
  `if (interactive())`. 'tcltk' and 'shiny' are in Suggests and are checked
  with `requireNamespace()` before use.
* In interactive sessions, `print()` methods may also send the output to a
  'Tcl/Tk' text window; in non-interactive sessions (and with
  `options(tsexplorer.window = FALSE)`) they print to the console.
* The package writes no files.
