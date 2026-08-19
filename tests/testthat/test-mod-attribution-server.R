source(file.path("R", "brinson.R"))
source(file.path("R", "persistence.R"))
source(file.path("R", "mod_attribution_server.R"))

test_that("the module can load persisted data during initialization", {
  database_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(database_path), add = TRUE)
  initialize_database(database_path)

  metadata <- metadata_from_returns(data.frame(
    ticker = "EQUITY",
    date = as.Date("2026-01-01"),
    name = "Equity",
    value = 0.01
  ))
  db_replace(database_path, "metadata", transform(metadata, enabled = as.integer(enabled)))

  expect_no_error(
    shiny::testServer(mod_attribution_server, args = list(database_path = database_path), {
      expect_equal(shiny::isolate(metadata())$ticker, "EQUITY")
    })
  )
})
