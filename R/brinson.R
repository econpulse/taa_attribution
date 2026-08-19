required_return_columns <- c("ticker", "date", "name", "value")

empty_returns <- function() {
  data.frame(
    ticker = character(), date = as.Date(character()), name = character(),
    value = numeric(), stringsAsFactors = FALSE
  )
}

validate_returns <- function(data) {
  names(data) <- tolower(trimws(names(data)))
  missing <- setdiff(required_return_columns, names(data))
  if (length(missing)) {
    stop("Missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  data <- data[required_return_columns]
  data$ticker <- trimws(as.character(data$ticker))
  data$name <- as.character(data$name)
  if (is.numeric(data$date)) {
    data$date <- as.Date(data$date, origin = "1899-12-30")
  } else {
    data$date <- as.Date(data$date)
  }
  data$value <- suppressWarnings(as.numeric(data$value))
  invalid <- !nzchar(data$ticker) | is.na(data$date) | is.na(data$value)
  if (any(invalid)) {
    stop(sum(invalid), " row(s) contain an invalid ticker, date, or value.",
         call. = FALSE)
  }
  if (anyDuplicated(data[c("ticker", "date")])) {
    stop("Each ticker/date combination must be unique.", call. = FALSE)
  }
  data[order(data$date, data$ticker), , drop = FALSE]
}

read_return_file <- function(path, filename) {
  extension <- tolower(tools::file_ext(filename))
  if (extension != "xlsx") {
    stop("Upload a .xlsx file.", call. = FALSE)
  }
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required for Excel uploads.", call. = FALSE)
  }
  prices <- as.data.frame(readxl::read_excel(path, .name_repair = "minimal"),
    check.names = FALSE)
  wide_prices_to_returns(prices)
}

wide_prices_to_returns <- function(data) {
  if (ncol(data) < 3L) {
    stop("The workbook must contain ticker, name, and at least one date column.",
      call. = FALSE)
  }

  names(data)[1:2] <- c("ticker", "name")
  date_labels <- trimws(names(data)[-(1:2)])
  excel_dates <- suppressWarnings(as.numeric(date_labels))
  if (anyNA(excel_dates)) {
    stop("Every column after ticker and name must be an Excel serial date.",
      call. = FALSE)
  }
  dates <- as.Date(excel_dates, origin = "1899-12-30")
  if (anyNA(dates) || anyDuplicated(dates)) {
    stop("Price date columns must contain unique, valid Excel serial dates.",
      call. = FALSE)
  }

  rows <- lapply(seq_len(nrow(data)), function(i) {
    ticker <- trimws(as.character(data$ticker[i]))
    name <- as.character(data$name[i])
    raw_prices <- unlist(data[i, -(1:2), drop = FALSE], use.names = FALSE)
    prices <- suppressWarnings(as.numeric(raw_prices))
    invalid_number <- !is.na(raw_prices) & nzchar(trimws(as.character(raw_prices))) &
      is.na(prices)
    if (any(invalid_number)) {
      stop("Prices must be numeric (ticker: ", ticker, ").", call. = FALSE)
    }
    observed <- !is.na(prices)
    prices <- prices[observed]
    observed_dates <- dates[observed]
    if (any(!is.finite(prices) | prices <= 0)) {
      stop("Prices must be finite and greater than zero (ticker: ", ticker, ").",
        call. = FALSE)
    }
    order_index <- order(observed_dates)
    prices <- prices[order_index]
    observed_dates <- observed_dates[order_index]
    if (length(prices) < 2L) return(empty_returns())
    data.frame(
      ticker = rep(ticker, length(prices) - 1L),
      date = observed_dates[-1L],
      name = rep(name, length(prices) - 1L),
      value = prices[-1L] / prices[-length(prices)] - 1,
      stringsAsFactors = FALSE
    )
  })
  validate_returns(do.call(rbind, rows))
}

metadata_from_returns <- function(data) {
  tickers <- unique(data[c("ticker", "name")])
  tickers <- tickers[!duplicated(tickers$ticker), , drop = FALSE]
  row_count <- nrow(tickers)
  data.frame(
    ticker = tickers$ticker,
    name = tickers$name,
    instrument_type = rep("asset", row_count),
    asset_class = rep("Unclassified", row_count),
    currency = rep("BASE", row_count),
    return_type = rep("simple", row_count),
    enabled = rep(TRUE, row_count),
    stringsAsFactors = FALSE
  )
}

period_key <- function(date, frequency) {
  if (frequency == "Full horizon") return(rep("Full horizon", length(date)))
  if (frequency == "Daily") return(format(date, "%Y-%m-%d"))
  if (frequency == "Monthly") return(format(date, "%Y-%m"))
  if (frequency == "Quarterly") {
    return(paste0(format(date, "%Y"), "-Q", (as.integer(format(date, "%m")) - 1L) %/% 3L + 1L))
  }
  format(date, "%Y")
}

compound_return <- function(x, type = "simple") {
  if (!length(x)) return(NA_real_)
  if (type == "log") return(exp(sum(x)) - 1)
  prod(1 + x) - 1
}

prepare_period_returns <- function(returns, metadata, start, end, frequency) {
  metadata$name <- NULL
  data <- merge(returns, metadata, by = "ticker", all.x = TRUE)
  data <- data[data$enabled & data$date >= start & data$date <= end, , drop = FALSE]
  if (!nrow(data)) stop("No enabled observations in the selected period.", call. = FALSE)
  data$period <- period_key(data$date, frequency)
  groups <- split(data, interaction(data$ticker, data$period, drop = TRUE))
  rows <- lapply(groups, function(x) data.frame(
    ticker = x$ticker[1], period = x$period[1], name = x$name[1],
    instrument_type = x$instrument_type[1], asset_class = x$asset_class[1],
    currency = x$currency[1],
    return = compound_return(x$value, x$return_type[1]),
    stringsAsFactors = FALSE
  ))
  do.call(rbind, rows)
}

normalize_weights <- function(weights, label) {
  weights$weight <- as.numeric(weights$weight)
  if (any(!is.finite(weights$weight)) || any(weights$weight < 0)) {
    stop(label, " weights must be finite and non-negative.", call. = FALSE)
  }
  total <- sum(weights$weight)
  if (total <= 0) stop(label, " weights must sum to more than zero.", call. = FALSE)
  weights$weight <- weights$weight / total
  weights
}

brinson_attribution <- function(period_returns, metadata, portfolio_weights,
                                benchmark_weights, base_currency = "BASE") {
  available <- metadata$ticker[metadata$instrument_type == "asset" & metadata$enabled]
  portfolio_weights <- portfolio_weights[portfolio_weights$ticker %in% available, , drop = FALSE]
  benchmark_weights <- benchmark_weights[benchmark_weights$ticker %in% available, , drop = FALSE]
  portfolio_weights <- normalize_weights(portfolio_weights, "Portfolio")
  benchmark_weights <- normalize_weights(benchmark_weights, "Benchmark")
  assets <- period_returns[period_returns$instrument_type == "asset", , drop = FALSE]
  fx <- period_returns[period_returns$instrument_type == "currency", c("period", "currency", "return")]
  if (anyDuplicated(fx[c("period", "currency")])) {
    stop("Define at most one FX series for each currency.", call. = FALSE)
  }
  names(fx)[3] <- "fx_return"
  assets <- merge(assets, fx, by = c("period", "currency"), all.x = TRUE)
  assets$fx_return[assets$currency == base_currency] <- 0
  missing_fx <- is.na(assets$fx_return) & assets$currency != base_currency
  if (any(missing_fx)) {
    missing_currency <- unique(assets$currency[missing_fx])
    stop("Missing FX return series for: ", paste(missing_currency, collapse = ", "),
         ". Add one currency series per currency and period.", call. = FALSE)
  }
  assets$base_return <- (1 + assets$return) * (1 + assets$fx_return) - 1

  build_side <- function(weights, prefix) {
    x <- merge(assets, weights, by = "ticker")
    period_weight <- aggregate(x$weight, list(period = x$period), sum)
    incomplete <- period_weight$period[abs(period_weight$x - 1) > 1e-8]
    if (length(incomplete)) {
      stop(prefix, " has missing asset returns in period(s): ",
           paste(incomplete, collapse = ", "), call. = FALSE)
    }
    x$weighted_local <- x$weight * x$return
    x$weighted_base <- x$weight * x$base_return
    x$weighted_fx <- x$weight * (x$base_return - x$return)
    keys <- interaction(x$period, x$asset_class, drop = TRUE)
    result <- do.call(rbind, lapply(split(x, keys), function(y) data.frame(
      period = y$period[1], asset_class = y$asset_class[1],
      weight = sum(y$weight),
      local_return = if (sum(y$weight) == 0) 0 else sum(y$weighted_local) / sum(y$weight),
      base_return = if (sum(y$weight) == 0) 0 else sum(y$weighted_base) / sum(y$weight),
      currency_contribution = sum(y$weighted_fx), stringsAsFactors = FALSE
    )))
    names(result)[3:6] <- paste0(prefix, c("_weight", "_local_return", "_base_return", "_currency"))
    result
  }

  p <- build_side(portfolio_weights, "portfolio")
  b <- build_side(benchmark_weights, "benchmark")
  result <- merge(p, b, by = c("period", "asset_class"), all = TRUE)
  result[is.na(result)] <- 0
  benchmark_total <- aggregate(
    result$benchmark_weight * result$benchmark_local_return,
    list(period = result$period), sum
  )
  names(benchmark_total)[2] <- "benchmark_total"
  result <- merge(result, benchmark_total, by = "period")
  result$allocation <- (result$portfolio_weight - result$benchmark_weight) *
    (result$benchmark_local_return - result$benchmark_total)
  result$selection <- result$benchmark_weight *
    (result$portfolio_local_return - result$benchmark_local_return)
  result$interaction <- (result$portfolio_weight - result$benchmark_weight) *
    (result$portfolio_local_return - result$benchmark_local_return)
  result$currency <- result$portfolio_currency - result$benchmark_currency
  result$total_effect <- result$allocation + result$selection + result$interaction + result$currency
  result[order(result$period, result$asset_class), c(
    "period", "asset_class", "portfolio_weight", "benchmark_weight",
    "portfolio_base_return", "benchmark_base_return", "allocation",
    "selection", "interaction", "currency", "total_effect"
  )]
}
