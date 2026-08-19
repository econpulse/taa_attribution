mod_attribution_server <- function(id, database_path = getOption(
  "taa.database", file.path("data", "taa-attribution.sqlite"))) {
  shiny::moduleServer(id, function(input, output, session) {
    initialize_database(database_path)
    returns <- shiny::reactiveVal(empty_returns())
    metadata <- shiny::reactiveVal(metadata_from_returns(empty_returns()))
    portfolios <- shiny::reactiveVal(data.frame(portfolio = character(), base_currency = character(),
      ticker = character(), weight = numeric(), stringsAsFactors = FALSE))
    rebalancing_dates <- shiny::reactiveVal(as.Date(character()))
    results <- shiny::reactiveVal(NULL)
    upload_message <- shiny::reactiveVal("No file uploaded.")

    load_database <- function() {
      r <- db_read(database_path, "returns")
      if (nrow(r)) { r$date <- as.Date(r$date); r$value <- as.numeric(r$value) }
      returns(if (nrow(r)) validate_returns(r) else empty_returns())
      m <- db_read(database_path, "metadata")
      if (nrow(m)) { m$enabled <- as.logical(m$enabled); metadata(m) }
      p <- db_read(database_path, "portfolios")
      if (nrow(p)) p$weight <- as.numeric(p$weight)
      portfolios(p)
      d <- db_read(database_path, "rebalancing_dates")
      rebalancing_dates(as.Date(d$date))
      update_choices()
    }
    update_choices <- function() {
      # This helper also runs during module initialization, before Shiny has
      # entered a reactive consumer.  Reading reactive values in isolate()
      # keeps UI updates usable both at startup and from observers.
      meta <- shiny::isolate(metadata())
      shiny::updateSelectInput(session, "meta_ticker", choices = meta$ticker)
      assets <- meta$ticker[meta$instrument_type == "asset" & meta$enabled]
      shiny::updateSelectInput(session, "weight_ticker", choices = assets)
      names <- unique(shiny::isolate(portfolios())$portfolio)
      shiny::updateSelectInput(session, "portfolio_a", choices = names)
      shiny::updateSelectInput(session, "portfolio_b", choices = names,
        selected = if (length(names) > 1L) names[2L] else names)
    }
    load_database()

    shiny::observeEvent(input$return_file, {
      tryCatch({
        data <- read_return_file(input$return_file$datapath, input$return_file$name)
        meta <- metadata_from_returns(data)
        meta$currency <- "CHF"; meta$fx_base <- "EUR"; meta$fx_quote <- "USD"
        metadata(meta); returns(data)
        db_replace(database_path, "returns", transform(data, date = as.character(date)))
        db_replace(database_path, "metadata", transform(meta, enabled = as.integer(enabled)))
        update_choices()
        shiny::updateDateRangeInput(session, "date_range", start = min(data$date), end = max(data$date))
        upload_message(paste(nrow(data), "observations imported and saved."))
      }, error = function(e) upload_message(paste("Import failed:", conditionMessage(e))))
    })
    shiny::observeEvent(input$meta_ticker, {
      x <- metadata()[metadata()$ticker == input$meta_ticker, , drop = FALSE]
      if (!nrow(x)) return()
      for (field in c("instrument_type", "currency", "fx_base", "fx_quote", "return_type"))
        shiny::updateSelectInput(session, field, selected = x[[field]])
      shiny::updateTextInput(session, "meta_name", value = x$name)
      shiny::updateTextInput(session, "asset_class", value = x$asset_class)
      shiny::updateCheckboxInput(session, "enabled", value = x$enabled)
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$save_metadata, {
      shiny::req(input$meta_ticker)
      x <- metadata(); i <- match(input$meta_ticker, x$ticker)
      x[i, c("name", "instrument_type", "asset_class", "currency", "fx_base", "fx_quote",
        "return_type", "enabled")] <- list(input$meta_name, input$instrument_type,
          input$asset_class, input$currency, input$fx_base, input$fx_quote,
          input$return_type, input$enabled)
      if (input$instrument_type == "currency" && input$fx_base == input$fx_quote)
        return(shiny::showNotification("FX base and quote must differ.", type = "error"))
      metadata(x); db_replace(database_path, "metadata", transform(x, enabled = as.integer(enabled)))
      update_choices()
    })
    shiny::observeEvent(input$save_weight, {
      shiny::req(nzchar(trimws(input$portfolio_name)), input$weight_ticker)
      x <- portfolios(); key <- x$portfolio == input$portfolio_name & x$ticker == input$weight_ticker
      row <- data.frame(portfolio = input$portfolio_name, base_currency = input$portfolio_base_currency,
        ticker = input$weight_ticker, weight = input$portfolio_weight)
      x <- rbind(x[!key, , drop = FALSE], row); portfolios(x)
      db_replace(database_path, "portfolios", x); update_choices()
    })
    shiny::observeEvent(input$equal_weights, {
      assets <- metadata()$ticker[metadata()$instrument_type == "asset" & metadata()$enabled]
      shiny::req(length(assets), nzchar(input$portfolio_name))
      x <- portfolios(); x <- x[x$portfolio != input$portfolio_name, , drop = FALSE]
      x <- rbind(x, data.frame(portfolio = input$portfolio_name,
        base_currency = input$portfolio_base_currency, ticker = assets, weight = 1 / length(assets)))
      portfolios(x); db_replace(database_path, "portfolios", x); update_choices()
    })
    shiny::observeEvent(input$add_rebalancing_date, {
      dates <- sort(unique(c(rebalancing_dates(), as.Date(input$rebalancing_date))))
      rebalancing_dates(dates)
      db_replace(database_path, "rebalancing_dates", data.frame(date = as.character(dates)))
    })
    shiny::observeEvent(input$calculate, {
      tryCatch({
        shiny::req(input$portfolio_a, input$portfolio_b, input$portfolio_a != input$portfolio_b)
        frequency <- if (input$schedule_mode == "custom") "Custom" else input$frequency
        periodic <- prepare_period_returns(returns(), metadata(), input$date_range[1],
          input$date_range[2], frequency, rebalancing_dates())
        p <- portfolios(); a <- p[p$portfolio == input$portfolio_a, ]; b <- p[p$portfolio == input$portfolio_b, ]
        if (a$base_currency[1] != b$base_currency[1]) stop("Compared portfolios must use the same base currency.")
        results(brinson_attribution(periodic, metadata(), a[c("ticker", "weight")],
          b[c("ticker", "weight")], a$base_currency[1]))
      }, error = function(e) shiny::showNotification(conditionMessage(e), type = "error", duration = NULL))
    })
    shiny::observeEvent(input$restore_database, {
      shiny::req(input$database_file)
      tryCatch({ validate_database(input$database_file$datapath)
        file.copy(input$database_file$datapath, database_path, overwrite = TRUE)
        load_database(); shiny::showNotification("Backup restored.")
      }, error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
    })

    output$upload_status <- shiny::renderUI(shiny::div(class = "text-muted", upload_message()))
    output$metadata_table <- DT::renderDT(metadata(), options = list(scrollX = TRUE))
    output$weights_table <- DT::renderDT(portfolios(), options = list(pageLength = 15))
    output$rebalancing_table <- DT::renderDT(data.frame(date = rebalancing_dates()))
    output$attribution_table <- DT::renderDT({ shiny::req(results()); results() }, options = list(scrollX = TRUE))
    output$result_title <- shiny::renderText(paste(input$portfolio_a, "vs.", input$portfolio_b))
    output$attribution_plot <- shiny::renderPlot({
      shiny::req(results()); x <- results(); effects <- c("allocation", "selection", "interaction", "currency")
      totals <- aggregate(x[effects], list(period = x$period), sum)
      graphics::barplot(t(as.matrix(totals[effects])), names.arg = totals$period, beside = FALSE,
        col = c("#0d6efd", "#20c997", "#ffc107", "#6f42c1"), las = 2,
        ylab = "Contribution", xlab = "Period")
      graphics::legend("topright", legend = effects, fill = c("#0d6efd", "#20c997", "#ffc107", "#6f42c1"))
    })
    output$download_results <- shiny::downloadHandler(
      filename = function() paste0("attribution-", Sys.Date(), ".csv"),
      content = function(file) utils::write.csv(results(), file, row.names = FALSE))
    output$download_database <- shiny::downloadHandler(
      filename = function() paste0("taa-attribution-backup-", Sys.Date(), ".sqlite"),
      content = function(file) file.copy(database_path, file, overwrite = TRUE))
  })
}
