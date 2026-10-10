test_that("testhet matches the reference values", {
  th <- ref("testhet")
  cases <- list(airpas = testhet(airpas), airpas_cuts = testhet(airpas, c(48, 96)),
                airpas_matrix = testhet(airpas, rbind(c(1, 30), c(50, 90), c(100, 144))),
                scc = testhet(scc))
  for (nm in names(cases)) {
    r <- cases[[nm]]
    expect_ref(r$samples, th[[nm]]$timecuts)
    # degrees of freedom n - 1 (column 6 of the reference)
    expect_ref(cbind(r$table$f, r$table$p_value), th[[nm]]$table[, c(4, 6)])
  }
})

test_that("testhet: time cuts and agreement with var.test", {
  r <- testhet(airpas, c(48, 96))
  expect_equal(unname(r$samples), rbind(c(1, 48), c(49, 96), c(97, 144)))
  vt <- stats::var.test(airpas[1:48], airpas[49:96])
  expect_equal(r$table$p_value[1], vt$p.value, tolerance = 1e-10)
  # invalid cuts fall back to the default three subsamples
  expect_equal(nrow(testhet(airpas, 2)$samples), 3L)
  # rows of a matrix starting before observation 5 are removed
  # (only after the first one)
  r <- testhet(airpas, rbind(c(1, 40), c(3, 60), c(70, 144)))
  expect_equal(unname(r$samples), rbind(c(1, 40), c(70, 144)))
})

test_that("vboxcox matches the reference values (Guerrero method and fminsearch)", {
  bc <- ref("vboxcox")
  r <- vboxcox(airpas, group = 12)
  expect_ref(r$lambdas, bc$airpas$lambdas)
  expect_ref(as.matrix(r$grid[, 2:7]), cbind(bc$airpas$grid, bc$airpas$grid_std))
  r <- vboxcox(lydia_pinkham, group = 6, axislambdas = seq(-1, 1, 0.25), series = 2)
  expect_ref(r$lambdas, bc$lydia$lambdas)
  expect_ref(as.matrix(r$grid[, 2:7]), cbind(bc$lydia$grid, bc$lydia$grid_std))
})

test_that("vboxcox transforms with given lambdas", {
  r <- vboxcox(airpas, lambdas = 0)
  expect_false(r$estimated)
  expect_equal(as.vector(r$transformed), log(as.vector(airpas)))
  r <- vboxcox(scc, lambdas = c(1, 0.5))
  expect_equal(unname(r$lambdas), c(1, 0.5, 0.5))
})
