source(file.path("R", "brinson.R"))

test_that("empty returns produce typed, empty metadata", {
  metadata <- metadata_from_returns(empty_returns())

  expect_s3_class(metadata, "data.frame")
  expect_identical(nrow(metadata), 0L)
  expect_named(metadata, c(
    "ticker", "name", "instrument_type", "asset_class", "currency",
    "return_type", "enabled"
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
  expect_equal(metadata$currency, c("BASE", "BASE"))
  expect_true(all(metadata$enabled))
})
