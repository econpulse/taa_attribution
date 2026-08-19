source(file.path("R", "brinson.R"))

test_that("empty returns produce typed, empty metadata", {
  metadata <- metadata_from_returns(empty_returns())

  expect_s3_class(metadata, "data.frame")
  expect_identical(nrow(metadata), 0L)
  expect_named(metadata, c(
    "ticker", "name", "instrument_type", "asset_class", "currency",
    "fx_base", "fx_quote", "return_type", "enabled"
  ))
  expect_type(metadata$enabled, "logical")
})

test_that("metadata defaults are repeated for every ticker", {
  returns <- data.frame(
    ticker = c("EQUITY", "BOND"),
    date = as.Date(c("2026-01-31", "2026-01-31")),
    name = c("Equity", "Bond"),
    value = c(0.02, 0.01),
    stringsAsFactors = FALSE
  )

  metadata <- metadata_from_returns(returns)

  expect_equal(nrow(metadata), 2L)
  expect_equal(metadata$instrument_type, c("asset", "asset"))
  expect_equal(metadata$asset_class, c("Unclassified", "Unclassified"))
  expect_equal(metadata$currency, c("CHF", "CHF"))
  expect_true(all(metadata$enabled))
})

test_that("prices are grouped by ticker and sorted before returns are calculated", {
  prices <- data.frame(
    Code = c("EQUITY", "EQUITY"), Description = c("Equity", "Equity"),
    `46025` = c(121, NA), `46023` = c(NA, 100), `46024` = c(110, NA),
    check.names = FALSE
  )
  returns <- wide_prices_to_returns(prices)
  expect_equal(returns$date, as.Date(c("2026-01-02", "2026-01-03")))
  expect_equal(returns$value, c(.1, .1))
})

test_that("custom periods use sorted rebalancing dates", {
  dates <- as.Date(c("2026-02-02", "2026-01-15", "2026-01-20"))
  expect_equal(custom_period_key(dates, as.Date(c("2026-02-01", "2026-01-01"))),
    c("2026-02-01", "2026-01-01", "2026-01-01"))
})

test_that("wide Excel prices are reshaped and converted to simple returns", {
  prices <- data.frame(
    Code = c("EQUITY", "BOND"),
    Description = c("Equity", "Bond"),
    `46024` = c(110, 99),
    `46023` = c(100, 100),
    check.names = FALSE
  )

  returns <- wide_prices_to_returns(prices)

  expect_named(returns, c("ticker", "date", "name", "value"))
  expect_equal(returns$date, as.Date(rep("2026-01-02", 2)))
  expect_equal(returns$value, c(-0.01, 0.1))
  expect_equal(returns$ticker, c("BOND", "EQUITY"))
})

test_that("wide prices skip blanks and reject non-date headings", {
  prices <- data.frame(
    id = "EQUITY", label = "Equity", `46023` = 100,
    `46024` = NA_real_, `46025` = 121, check.names = FALSE
  )
  expect_equal(wide_prices_to_returns(prices)$value, 0.21)

  names(prices)[3] <- "2025-12-02"
  expect_error(wide_prices_to_returns(prices), "Excel serial date")
})
