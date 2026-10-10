check_adf <- function(r, x) {
  expect_ref(cbind(r$none$rho, r$none$t), cbind(as.vector(x$Rhont), as.vector(x$tRhont)))
  expect_ref(cbind(r$const$rho, r$const$t, r$const$const, r$const$t_const),
             cbind(as.vector(x$Rho), as.vector(x$tRho), as.vector(x$Alfa), as.vector(x$tAlfa)))
  expect_ref(cbind(r$trend$rho, r$trend$t, r$trend$const, r$trend$t_const, r$trend$trend,
                   r$trend$t_trend),
             cbind(as.vector(x$Rhot), as.vector(x$tRhot), as.vector(x$Alfat), as.vector(x$tAlfat),
                   as.vector(x$D), as.vector(x$tD)))
  # F statistics divided by the number of restrictions and
  # Phi3 computed with the coefficient of the model with trend.
  expect_ref(r$const$f, as.vector(x$F_fixed))
  expect_ref(r$trend$f, as.vector(x$Ft_fixed))
  # p-values of the t statistics (stored triangulation)
  expect_ref(cbind(r$none$p_t, r$const$p_t, r$trend$p_t),
             cbind(as.vector(x$p_tRhont), as.vector(x$p_tRho), as.vector(x$p_tRhot)))
}

test_that("adftest matches the reference values", {
  ad <- ref("adftest")
  check_adf(adftest(la(), 1:4), ad$la)
  check_adf(adftest(lp(), 3), ad$lp)
  check_adf(adftest(nile, 1:2), ad$nile)
})

test_that("adftest: lags, structure and agreement with urca", {
  r <- adftest(la())
  expect_equal(r$call$lags, 1:12)
  r <- adftest(lp())
  expect_equal(r$call$lags, 7L)
  expect_equal(nrow(r$const), 2L)
  expect_equal(tsexplorer:::tsx_unitroot_lags(100, 144, 1), 72L)
  expect_error(adftest(la(), 100), "lags")
  testthat::skip_if_not_installed("urca")
  u <- urca::ur.df(as.vector(la()), type = "trend", lags = 3)
  r <- adftest(la(), 3)
  expect_equal(r$trend$t, unname(u@teststat[1, "tau3"]), tolerance = 1e-8)
  expect_equal(r$trend$f, unname(u@teststat[1, "phi3"]), tolerance = 1e-8)
  u <- urca::ur.df(as.vector(la()), type = "drift", lags = 3)
  expect_equal(r$const$f, unname(u@teststat[1, "phi1"]), tolerance = 1e-8)
})

test_that("vphillips matches the reference values", {
  # the correction term is divided by the standard error of the regression
  pp <- ref("vphillips")
  for (nm in c("la", "lp")) {
    r <- if (nm == "la") vphillips(la(), 1:3, 4) else vphillips(lp(), 3)
    x <- pp[[nm]]
    expect_ref(cbind(r$none$rho, r$const$rho, r$trend$rho),
               cbind(as.vector(x$rho_none), as.vector(x$rho_const), as.vector(x$rho_trend)))
    expect_ref(cbind(r$none$z_t, r$const$z_t, r$trend$z_t),
               cbind(as.vector(x$z_none_fixed), as.vector(x$z_const_fixed),
                     as.vector(x$z_trend_fixed)))
  }
  # each model uses its own statistic for the p-value
  r <- vphillips(la(), 1:3, 4)
  expect_equal(r$const$p_value, adfcritical(r$const$z_t, r$n, "t_const"))
  expect_equal(r$trend$p_value, adfcritical(r$trend$z_t, r$n, "t_trend"))
})

test_that("vphillips without lags agrees with the textbook statistic", {
  # Z(t) of Phillips and Perron (1988) with Bartlett weights, computed directly
  z <- as.vector(la())
  n <- length(z)
  r <- vphillips(z, lags = 0, ncovs = 4)
  y <- z[2:n]
  x <- cbind(z[1:(n - 1)], 1)
  fit <- stats::lm.fit(x, y)
  e <- fit$residuals
  s2 <- sum(e^2) / (length(e) - 2)
  se <- sqrt(s2 * solve(crossprod(x))[1, 1])
  t0 <- (fit$coefficients[1] - 1) / se
  g0 <- sum(e^2) / n
  lam <- g0
  for (k in 1:4) lam <- lam + 2 * (1 - k / 5) * sum(e[-(1:k)] * e[1:(length(e) - k)]) / n
  zt <- sqrt(g0 / lam) * t0 - 0.5 * (lam - g0) / sqrt(lam) * n * se / sqrt(s2)
  expect_equal(r$const$z_t, unname(zt), tolerance = 1e-10)
})

test_that("johansentest matches the reference values", {
  jo <- ref("johansentest")
  # p-values of the models with constant and trend are checked below
  cols <- c("stat_none", "p_none", "stat_const", "stat_trend")
  ref_cols <- c(1, 2, 3, 5)
  r <- johansentest(lp(), 3)
  expect_ref(as.matrix(r$table[, cols]), jo$lp$table[, ref_cols])
  expect_ref(as.matrix(r$eigen[, -1]), jo$lp$table2)
  expect_equal(r$table$type, c("max", "trace", "max"))
  expect_ref(as.matrix(johansentest(la(), 2:4)$table[, cols]), jo$la$table[, ref_cols])
  sv <- apply(ref_input("sim_var3.csv"), 2, cumsum)
  r <- johansentest(sv, 2)
  expect_ref(as.matrix(r$table[, cols]), jo$simvar$table[, ref_cols])
  expect_true(all(is.na(r$table$p_trend)))
})

test_that("johansentest p-values use the tables of each model", {
  # 5% critical values of Johansen-Juselius (1990), Table A1 (unrestricted
  # constant) and Osterwald-Lenum (1992), Table 0 (no deterministic terms)
  p <- tsexplorer:::tsx_johansen_p
  expect_equal(p(c(3.962, 14.036, 15.197, 29.509), c(1, 2, 2, 3),
                 c("max", "max", "trace", "trace"), 3), rep(0.05, 4))
  expect_equal(p(c(11.44, 12.53), c(2, 2), c("max", "trace"), 1), c(0.05, 0.05))
  r <- johansentest(lp(), 3)
  expect_equal(r$table$p_const, p(r$table$stat_const, 2 - r$table$h0, r$table$type, 3))
})

test_that("johansentest eigenvalues agree with urca", {
  testthat::skip_if_not_installed("urca")
  y <- as.matrix(lp())
  r <- johansentest(y, 3)
  u <- urca::ca.jo(y, ecdet = "none", K = 3, spec = "transitory")
  expect_equal(r$eigen$eigen_const, unname(u@lambda), tolerance = 1e-8)
})
