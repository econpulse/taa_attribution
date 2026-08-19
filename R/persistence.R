database_schema <- c("returns", "metadata", "portfolios", "rebalancing_dates")

initialize_database <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS returns (ticker TEXT, date TEXT, name TEXT, value REAL)")
  DBI::dbExecute(con, paste("CREATE TABLE IF NOT EXISTS metadata (ticker TEXT PRIMARY KEY, name TEXT,",
    "instrument_type TEXT, asset_class TEXT, currency TEXT, fx_base TEXT, fx_quote TEXT,",
    "return_type TEXT, enabled INTEGER)"))
  DBI::dbExecute(con, paste("CREATE TABLE IF NOT EXISTS portfolios (portfolio TEXT, base_currency TEXT,",
    "ticker TEXT, weight REAL, PRIMARY KEY (portfolio, ticker))"))
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS rebalancing_dates (date TEXT PRIMARY KEY)")
  invisible(path)
}

db_read <- function(path, table) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbReadTable(con, table)
}

db_replace <- function(path, table, data) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbWriteTable(con, table, data, overwrite = TRUE)
  invisible(data)
}

validate_database <- function(path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  missing <- setdiff(database_schema, DBI::dbListTables(con))
  if (length(missing)) stop("Backup is missing table(s): ", paste(missing, collapse = ", "), call. = FALSE)
  TRUE
}
