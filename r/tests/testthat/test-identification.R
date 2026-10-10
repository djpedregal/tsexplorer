check_vident <- function(r, x) {
  t <- r$table
  expect_ref(cbind(t$acf, t$se_acf, t$q_lb, t$p_lb, t$pacf, t$se_pacf, t$q_mt, t$p_mt),
             cbind(x$sacf, x$seacf, x$Q, x$PQ, x$spacf, x$sepacf, x$Qmt, x$PQmt))
}

test_that("vident matches the reference values (with and without missing values)", {
  v <- ref("vident")
  check_vident(vident(dla()), v$dla)
  check_vident(vident(dla(), 24, npar = 2), v$dla_npar2)
  check_vident(vident(ref_input("sim_na.csv"), 20), v$sim_na)
  check_vident(vident(scc, 10, series = 2), v$scc_2)
  check_vident(vident(scc, 10, series = "y2"), v$scc_2)
})

test_that("vident: default lags, degrees of freedom and agreement with stats::acf", {
  r <- vident(dla())
  expect_equal(r$call$ncoef, min(38, ceiling(131 / 4 * 2)))
  r <- vident(dla(), 12, npar = 2)
  expect_true(all(is.na(r$table$p_lb[1:2])))
  a <- stats::acf(as.vector(dla()), lag.max = 12, plot = FALSE)$acf[-1]
  expect_equal(r$table$acf, a, tolerance = 1e-10)
  p <- stats::pacf(as.vector(dla()), lag.max = 12, plot = FALSE)$acf[, 1, 1]
  expect_equal(r$table$pacf, p, tolerance = 1e-10)
  lb <- stats::Box.test(as.vector(dla()), lag = 12, type = "Ljung-Box", fitdf = 2)
  expect_equal(r$table$q_lb[12], unname(lb$statistic), tolerance = 1e-10)
  # Box.test uses 1 - pchisq(): small p-values differ in the last digits
  expect_equal(r$table$p_lb[12], lb$p.value, tolerance = 1e-6)
})

check_vident2 <- function(r, x) {
  m <- length(r$series)
  nc <- r$call$ncoef
  blk <- function(arr) do.call(rbind, lapply(seq_len(nc + 1), function(k) arr[, , k]))
  d <- x$data
  expect_ref(blk(r$acf), d[, 1:m])
  expect_ref(blk(r$pacf), d[, (m + 1):(2 * m)])
  expect_ref(cbind(blk(r$se_acf), blk(r$se_pacf)), d[, (2 * m + 1):(4 * m)])
  # column 5 (p_q) is not compared
  expect_ref(as.matrix(r$stats[, c("aic", "sbc", "chi", "p_chi", "det_sigma")]),
             x$stats[, c(1:4, 6)])
  # Hosking (1980) / Li-McLeod (1981) portmanteau computed directly
  m <- length(r$series)
  r0i <- solve(r$acf[, , 1])
  n <- round(1 / r$se_acf[1, 1, 1]^2)
  cum <- cumsum(vapply(seq_len(nc), function(k) {
    rk <- r$acf[, , k + 1]
    sum(diag(t(rk) %*% r0i %*% rk %*% r0i))
  }, numeric(1)))
  k <- seq_len(nc)
  q <- n * cum + m^2 * k * (k + 1) / (2 * n)
  df <- m^2 * (k - r$call$npar)
  expected <- ifelse(df > 0, stats::pchisq(q, pmax(df, 1), lower.tail = FALSE), NA)
  expect_equal(r$stats$p_q, expected)
}

test_that("vident2 matches the reference values", {
  v <- ref("vident2")
  check_vident2(vident2(dlp(), 8, type = 0), v$dlp_type0)
  check_vident2(vident2(dlp(), 8, type = 1), v$dlp_type1)
  check_vident2(vident2(ref_input("sim_var3.csv"), 6, npar = 1), v$simvar_type0)
})

test_that("varsbc and varsbc2 match the reference values", {
  v <- ref("varsbc")
  expect_ref(as.matrix(varsbc(dla(), 15)$table[, -1]), v$dla$data)
  expect_ref(as.matrix(varsbc(scc, 5, series = "all")$table[, -1]), v$scc_all$data)
  expect_ref(varsbc2(dla(), 12)$table$sbc, v$varsbc2_dla$sbc)
  r <- varsbc(dla(), 15)
  expect_equal(r$best[["sbc"]], which.min(v$dla$data[, 2]) - 1)
})

test_that("varsbc with one series of several uses the dimension of the model", {
  # The LR statistic and its degrees of freedom use the number of series in
  # the model.
  v <- ref("varsbc")
  r <- varsbc(scc, 5, series = 2)
  expect_ref(as.matrix(r$table[, c("aicc", "sbc", "hqc")]), v$scc_2$data[, 1:3])
  expect_equal(r$table, varsbc(scc[, 2], 5)$table)
})

test_that("vgranger matches the reference values", {
  # Covariance of the coefficients: kron(inv(X'X), Sigma).
  v <- ref("vgranger")
  cols <- c("constraints", "f", "p_f", "chi2", "p_chi2")
  r <- vgranger(dlp(), 1:3)
  expect_equal(r$table$test, v$dlp$tests)
  expect_ref(as.matrix(r$table[, cols]), v$dlp$table_fixed)
  sv <- ref_input("sim_var3.csv")
  expect_ref(as.matrix(vgranger(sv, 1:2)$table[, cols]), v$simvar$table_fixed)
  expect_ref(as.matrix(vgranger(sv, c(1, 3), "a-bc bc-a")$table[, cols]), v$simvar_block$table_fixed)
})

test_that("vgranger agrees with a single equation Wald test", {
  # With one constraint block in one equation, the Wald statistic equals the
  # one computed from the OLS estimation of that equation.
  y <- sweep(dlp(), 2, colMeans(dlp()))
  n <- nrow(y)
  p <- 2
  x <- cbind(y[2:(n - 1), ], y[1:(n - 2), ])
  yy <- y[3:n, 1]
  fit <- stats::lm.fit(x, yy)
  sig <- sum(fit$residuals^2) / n
  b <- fit$coefficients[c(2, 4)]
  v <- solve(crossprod(x))[c(2, 4), c(2, 4)] * sig
  w <- drop(t(b) %*% solve(v) %*% b)
  r <- vgranger(dlp(), 1:p, "a-b")
  expect_equal(r$table$chi2, w, tolerance = 1e-10)
  expect_match(r$table$h0, "sales does not cause advertising")
})
