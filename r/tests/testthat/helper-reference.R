# Helpers to read the stored reference results and the shared input data.

ref_dir <- function() system.file("extdata", "reference", package = "tsexplorer")

ref <- function(name) {
  testthat::skip_if_not_installed("jsonlite")
  f <- file.path(ref_dir(), paste0(name, ".json"))
  testthat::skip_if_not(file.exists(f), paste("Reference file not found:", name))
  jsonlite::fromJSON(f)
}

ref_input <- function(file) {
  as.matrix(utils::read.csv(file.path(ref_dir(), "inputs", file)))
}

# Compare numbers ignoring names, dimensions and attributes.
expect_ref <- function(object, expected, tolerance = 1e-6) {
  testthat::expect_equal(as.numeric(unlist(object)), as.numeric(unlist(expected)),
                         tolerance = tolerance)
}

la <- function() log(airpas)
# log(airpas) without dates (for the forecasts given as matrices without dates)
lav <- function() as.vector(log(airpas))
dla <- function() vdif(log(airpas), c(1, 1), c(1, 12))
lp <- function() log(lydia_pinkham)
dlp <- function() vdif(log(lydia_pinkham))
