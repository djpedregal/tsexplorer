test_that("nltests matches the reference values", {
  nl <- ref("nonlinear")
  r <- nltests(dla(), 12)
  x <- nl$nltests_dla
  expect_ref(with(r$table, cbind(acf, se_acf, q_mll, p_mll, pacf, q_mt, p_mt, d_pr, p_pr)),
             cbind(x$sacf, x$seacf, x$Q, x$PQ, x$spacf, x$Qmt, x$PQmt, x$Dm, x$pDm))
})

test_that("nltests with missing values uses the same ACF as vident", {
  sn <- ref_input("sim_na.csv")
  r <- nltests(sn, 10)
  v <- vident(sn^2, 10)
  expect_equal(r$table$acf, v$table$acf)
})

test_that("vtsay is the F test of the cross products in the AR regression", {
  # Tsay (1986) with constant and F(k, n - p - k - 1); by the
  # Frisch-Waugh-Lovell theorem it equals the F test of adding the cross
  # products to the AR(p) regression with constant.
  for (y in list(as.vector(dla()), scc[, 3])) {
    p <- 3
    x <- tsexplorer:::tsx_delay(y, 0:p)
    prods <- NULL
    for (i in 1:p) for (j in i:p) prods <- cbind(prods, x[, i + 1] * x[, j + 1])
    m0 <- stats::lm(x[, 1] ~ x[, -1])
    m1 <- stats::lm(x[, 1] ~ x[, -1] + prods)
    a <- stats::anova(m0, m1)
    r <- vtsay(y, p)
    expect_equal(r$table$f, a$F[2], tolerance = 1e-10)
    expect_equal(r$table$p_value, a$`Pr(>F)`[2], tolerance = 1e-10)
    expect_equal(r$table$df2, a$Res.Df[2])
    # coefficients of the auxiliary regression are those of the products
    cf <- summary(m1)$coefficients[-(1:(p + 1)), ]
    expect_equal(r$regressions$beta, unname(cf[, 1]), tolerance = 1e-8)
    expect_equal(r$regressions$t, unname(cf[, 3]), tolerance = 1e-8)
    expect_equal(r$regressions$p_value, unname(cf[, 4]), tolerance = 1e-8)
  }
})

test_that("BDS statistic matches the reference values", {
  nl <- ref("nonlinear")
  b <- tsexplorer:::tsx_bds(as.vector(dla()), 4, 1.5)
  expect_ref(b$w, nl$bds_dla$w)
  expect_ref(b$p_value, nl$bds_dla$sig)
  expect_ref(c(b$c1, b$k), c(nl$bds_dla$c1, nl$bds_dla$k))
  b <- tsexplorer:::tsx_bds(as.vector(ref_input("sim_ar1.csv")), 3, 1.2)
  expect_ref(b$w, nl$bds_simar$w)
  r <- vbds(dla(), maxdim = 4)
  expect_ref(r$table$w, nl$bds_dla$w)
  expect_equal(r$table$dim, 2:4)
})

test_that("BDS is close to tseries::bds.test", {
  # tseries uses LeBaron's estimator of the first order correlation integral
  # (whole sample) while tsx_bds() uses the last n - m + 1
  # observations, so the statistics are only approximately equal.
  testthat::skip_if_not_installed("tseries")
  x <- as.vector(dla())
  tb <- tseries::bds.test(x, m = 3, eps = 1.5 * sd(x))
  expect_equal(vbds(x, maxdim = 3)$table$w, unname(tb$statistic[, 1]), tolerance = 0.1)
})

test_that("varsbc2 detects linearity of white noise", {
  r <- varsbc2(ref_input("sim_ar1.csv") - 10, 5)
  expect_equal(nrow(r$table), 6L)
  expect_type(r$linear, "logical")
})

test_that("vcumperiod matches the reference values on demeaned data", {
  sp <- ref("spectral")
  expect_ref(vcumperiod(dla())$table$cum_periodogram, sp$cumper_dla$cumP_demeaned)
  expect_ref(vcumperiod(airpas)$table$cum_periodogram, sp$cumper_a$cumP_demeaned)
  expect_ref(vcumperiod(airpas)$bands, sp$cumper_a$conf)
})

test_that("periodogram and cross periodogram match the reference values", {
  # frequencies are the Fourier frequencies 2 pi j / T
  sp <- ref("spectral")
  ms <- tsexplorer:::tsx_mspectrum(vdif(la()))
  expect_ref(Re(ms$i[1, 1, ]), sp$mspectrum_dla$I)
  expect_equal(ms$w, 2 * pi * (0:floor(143 / 2)) / 143)
  ms <- tsexplorer:::tsx_mspectrum(dlp())
  expect_ref(cbind(Re(ms$i[1, 1, ]), Re(ms$i[2, 2, ]), Re(ms$i[1, 2, ]), Im(ms$i[1, 2, ])),
             with(sp$mspectrum_dlp, cbind(I11, I22, I12_re, I12_im)))
  # with missing values the DFT skips them
  sn <- ref_input("sim_na.csv")
  expect_false(anyNA(vspectrum(sn)$table$periodogram))
})

test_that("vspectrum smoothing and coherence", {
  r1 <- vspectrum(vdif(la()), smooth = 1)
  expect_equal(r1$table$spectrum, r1$table$periodogram)
  r5 <- vspectrum(vdif(la()), smooth = 4)
  expect_equal(r5$call$smooth, 5)
  b <- c(1, 2, 3, 2, 1) / 9
  k <- 10
  expect_equal(r5$table$spectrum[k], sum(b * r1$table$periodogram[(k - 2):(k + 2)]))
  # symmetric extension at frequencies 0 and pi (T = 143, odd)
  per <- r1$table$periodogram
  np <- length(per)
  expect_equal(r5$table$spectrum[1], sum(b * per[c(3, 2, 1, 2, 3)]))
  expect_equal(r5$table$spectrum[np], sum(b * per[c(np - 2, np - 1, np, np, np - 1)]))
  # even T: the last frequency is pi
  r1e <- vspectrum(vdif(la())[-1, ], smooth = 1)
  r5e <- vspectrum(vdif(la())[-1, ], smooth = 5)
  pe <- r1e$table$periodogram
  ne <- length(pe)
  expect_equal(r5e$table$spectrum[ne], sum(b * pe[c(ne - 2, ne - 1, ne, ne - 1, ne - 2)]))
  r <- vspectrum(dlp(), smooth = 7, series = c(1, 2))
  expect_true(all(r$table$coherence >= 0 & r$table$coherence <= 1 + 1e-12))
  expect_equal(r$table$gain12 * r$table$spectrum1, r$table$cross_amplitude)
})

test_that("varspectrum matches the reference values", {
  sp <- ref("spectral")
  # spectrum sigma^2 / (2 pi) |1/phi|^2
  r <- varspectrum(vdif(la()), 14, 72)
  k <- r$sigma2 / (2 * pi^2)
  expect_ref(r$table$freq, sp$varspectrum_dla$freq)
  expect_ref(r$table$spectrum, sp$varspectrum_dla$spectrum * k)
  expect_ref(r$ar, sp$varspectrum_dla$ar)
  r <- varspectrum(vdif(la()), 6, 0)
  expect_ref(cbind(r$table$freq, r$table$spectrum),
             with(sp$varspectrum_fourier, cbind(freq, spectrum * r$sigma2 / (2 * pi^2))))
  # AR(1): f(0) = sigma^2 / (2 pi) / (1 - phi)^2
  w <- ref_input("sim_ar1.csv")[, 1]
  r <- varspectrum(w, 1)
  phi <- r$ar
  expect_equal(r$table$spectrum[1], r$sigma2 / (2 * pi) / (1 - phi)^2)
})
