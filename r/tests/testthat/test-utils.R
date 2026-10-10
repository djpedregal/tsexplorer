test_that("as_tsx_matrix converts the supported inputs", {
  expect_equal(dim(as_tsx_matrix(1:10)), c(10L, 1L))
  expect_equal(colnames(as_tsx_matrix(1:10)), "#1")
  expect_equal(colnames(as_tsx_matrix(cbind(a = 1:3, b = 4:6))), c("a", "b"))
  expect_equal(colnames(as_tsx_matrix(matrix(1:6, 3), names = "x y")), c("x", "y"))
  expect_equal(colnames(as_tsx_matrix(matrix(1:9, 3), names = "x")), c("x", "#2", "#3"))
  expect_equal(nrow(as_tsx_matrix(airpas)), 144L)
  expect_equal(colnames(as_tsx_matrix(data.frame(u = 1:3, v = 3:1))), c("u", "v"))
  expect_equal(colnames(as_tsx_matrix(lydia_pinkham)), c("advertising", "sales"))
})

test_that("as_tsx_matrix removes missing rows at the ends only (removeNaN)", {
  y <- cbind(c(NA, NA, 1, NA, 3, NA), c(NA, 2, 1, NA, 3, NA))
  out <- as_tsx_matrix(y)
  expect_equal(nrow(out), 4L)
  expect_equal(attr(out, "index"), 2:5)
  expect_equal(nrow(as_tsx_matrix(y, trim = FALSE)), 6L)
  expect_equal(as.vector(as_tsx_matrix(c(NaN, 1, 2))), c(1, 2))
})

test_that("invalid inputs give clear errors", {
  expect_error(as_tsx_matrix("a"), "numeric")
  expect_error(as_tsx_matrix(data.frame(a = 1:3, b = letters[1:3])), "numeric")
  expect_error(as_tsx_matrix(c(NA, NA)), "missing")
  expect_error(vident(airpas, series = 3), "series")
  expect_error(vident(airpas, series = "zz"), "not found")
  expect_error(vident2(airpas), "two series")
  expect_error(vgranger(airpas), "two series")
  expect_error(vident(airpas, ncoef = -1), "ncoef")
})

test_that("utilities match the reference values", {
  u <- ref("utilities")
  expect_ref(vdif(la(), c(1, 1), c(1, 12)), u$vdif_la)
  expect_ref(vdif(cbind(lp(), lp()), rbind(c(1, 0), c(1, 1)), c(1, 12)), u$vdif_lp)
  sv <- ref_input("sim_var3.csv")
  expect_ref(tsexplorer:::tsx_delay(sv[1:10, ], c(0, 1, 3)), u$delay)
  expect_ref(tsexplorer:::tsx_prctile(scc, c(10, 25, 50, 75, 90)), u$prctile)
  expect_ref(tsexplorer:::tsx_standardize(sv[1:10, ]), u$transform)
  sn <- ref_input("sim_na.csv")
  expect_ref(tsexplorer:::tsx_nancov(sn[1:30, , drop = FALSE]), u$nancov)
  expect_ref(meda(scc), u$meda)
  v <- tsexplorer:::tsx_mvar(sweep(sv, 2, colMeans(sv)), 1:2, TRUE)
  expect_ref(v$p, u$mvar_p)
  expect_ref(v$sigma, u$mvar_sigma)
  expect_ref(c(v$aic, v$sbc), c(u$mvar_aic, u$mvar_sbc))
  a <- tsexplorer:::tsx_auxvarsbc(dla() - mean(dla()), 3)
  expect_ref(c(a$fpe, a$aic, a$aicc, a$sbc, a$hqc, a$sigma), u$auxvarsbc)
  expect_ref(tsexplorer:::tsx_ksdensity(as.vector(dla()), u$ksdensity_x), u$ksdensity)
})

test_that("the Nelder-Mead simplex matches the reference values", {
  u <- ref("utilities")
  g <- tsexplorer:::tsx_fminsearch(function(l) tsexplorer:::tsx_guerrero(l, as.vector(airpas), 12), 1)
  expect_ref(g$par, u$fminsearch_guerrero)
  r <- tsexplorer:::tsx_fminsearch(function(x) 100 * (x[2] - x[1]^2)^2 + (1 - x[1])^2, c(-1.2, 1))
  expect_ref(r$par, u$fminsearch_rosen)
})

test_that("the signed rank test matches the reference values", {
  u <- ref("utilities")
  sr <- ref_input("sim_signrank.csv")
  # exact (n <= 15) and normal approximation with ties
  expect_ref(rev(tsexplorer:::tsx_signrank(sr[1:10, 1], sr[1:10, 2])), u$signrank[1, ])
  expect_ref(rev(tsexplorer:::tsx_signrank(sr[, 1], sr[, 2])), u$signrank[2, ])
  # without ties the exact p-value equals R's psignrank
  x <- c(1.83, 0.50, 1.62, 2.48, 1.68, 1.88, 1.55, 3.06, 1.30)
  y <- c(0.878, 0.647, 0.598, 2.05, 1.06, 1.29, 1.06, 3.14, 1.29)
  w <- tsexplorer:::tsx_signrank(x, y)
  expect_equal(w[2], stats::wilcox.test(x, y, paired = TRUE, exact = TRUE)$p.value)
})

test_that("adfcritical interpolates the Dickey-Fuller tables", {
  # exact at the tabulated points
  expect_equal(adfcritical(-2.89, 100, "t_const"), 0.05)
  expect_equal(adfcritical(-3.45, 100, "t_trend"), 0.05)
  expect_equal(adfcritical(4.71, 100, "f_const"), 0.05)
  expect_equal(adfcritical(c(-10, 10), 100, "t_none"), c(0, 1))
  expect_equal(adfcritical(c(0, 50), 100, "f_trend"), c(1, 0))
  # linear interpolation on the stored triangulation
  u <- ref("utilities")
  tabs <- c("t_none", "t_const", "t_trend", "f_const", "f_trend")
  for (d in 1:5) {
    g <- t(sapply(u$adfcritical_t, function(tt) adfcritical(u$adfcritical_x, tt, tabs[d])))
    expect_ref(g, u$adfcritical[d, , ], tolerance = 1e-10)
  }
})
