mod_attribution_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    returns <- shiny::reactiveVal(empty_returns())
    metadata <- shiny::reactiveVal(metadata_from_returns(empty_returns()))
    weights <- shiny::reactiveVal(data.frame(
      ticker = character(), portfolio = numeric(), benchmark = numeric(),
      stringsAsFactors = FALSE
    ))
    results <- shiny::reactiveVal(NULL)
    upload_message <- shiny::reactiveVal("No file uploaded.")

    shiny::observeEvent(input$return_file, {
      tryCatch({
        data <- read_return_file(input$return_file$datapath, input$return_file$name)
        returns(data)
        metadata(metadata_from_returns(data))
        assets <- unique(data$ticker)
        weights(data.frame(ticker = assets, portfolio = 0, benchmark = 0))
        update_inputs(data, metadata())
        shiny::updateDateRangeInput(session, "date_range",
          start = min(data$date), end = max(data$date),
          min = min(data$date), max = max(data$date))
        upload_message(paste(format(nrow(data), big.mark = ","), "observations imported."))
      }, error = function(error) upload_message(paste("Import failed:", conditionMessage(error))))
    })

    update_inputs <- function(data, meta) {
      shiny::updateSelectInput(session, "meta_ticker", choices = meta$ticker)
      asset_tickers <- meta$ticker[meta$instrument_type == "asset" & meta$enabled]
      shiny::updateSelectInput(session, "weight_ticker", choices = asset_tickers)
    }

    shiny::observeEvent(input$meta_ticker, {
      row <- metadata()[metadata()$ticker == input$meta_ticker, , drop = FALSE]
      if (!nrow(row)) return()
      shiny::updateTextInput(session, "meta_name", value = row$name)
      shiny::updateSelectInput(session, "instrument_type", selected = row$instrument_type)
      shiny::updateTextInput(session, "asset_class", value = row$asset_class)
      shiny::updateTextInput(session, "currency", value = row$currency)
      shiny::updateSelectInput(session, "return_type", selected = row$return_type)
      shiny::updateCheckboxInput(session, "enabled", value = row$enabled)
    }, ignoreInit = TRUE)

    shiny::observeEvent(input$save_metadata, {
      shiny::req(input$meta_ticker)
      data <- metadata()
      i <- match(input$meta_ticker, data$ticker)
      data[i, c("name", "instrument_type", "asset_class", "currency", "return_type", "enabled")] <-
        list(input$meta_name, input$instrument_type, input$asset_class,
          toupper(trimws(input$currency)), input$return_type, input$enabled)
      metadata(data)
      update_inputs(returns(), data)
    })

    shiny::observeEvent(input$save_weight, {
      shiny::req(input$weight_ticker)
      data <- weights()
      i <- match(input$weight_ticker, data$ticker)
      if (is.na(i)) {
        data <- rbind(data, data.frame(ticker = input$weight_ticker, portfolio = 0, benchmark = 0))
        i <- nrow(data)
      }
      data$portfolio[i] <- input$portfolio_weight
      data$benchmark[i] <- input$benchmark_weight
      weights(data)
    })

    shiny::observeEvent(input$equal_weights, {
      assets <- metadata()$ticker[metadata()$instrument_type == "asset" & metadata()$enabled]
      shiny::req(length(assets))
      weights(data.frame(ticker = assets, portfolio = 1 / length(assets), benchmark = 1 / length(assets)))
    })

    shiny::observeEvent(input$weight_ticker, {
      row <- weights()[weights()$ticker == input$weight_ticker, , drop = FALSE]
      if (!nrow(row)) return()
      shiny::updateNumericInput(session, "portfolio_weight", value = row$portfolio)
      shiny::updateNumericInput(session, "benchmark_weight", value = row$benchmark)
    }, ignoreInit = TRUE)

    shiny::observeEvent(input$calculate, {
      tryCatch({
        shiny::req(nrow(returns()), length(input$date_range) == 2)
        periodic <- prepare_period_returns(
          returns(), metadata(), input$date_range[1], input$date_range[2], input$frequency)
        definition <- weights()
        output <- brinson_attribution(
          periodic, metadata(),
          data.frame(ticker = definition$ticker, weight = definition$portfolio),
          data.frame(ticker = definition$ticker, weight = definition$benchmark),
          toupper(trimws(input$base_currency))
        )
        results(output)
        shiny::showNotification("Attribution completed.", type = "message")
      }, error = function(error) shiny::showNotification(
        conditionMessage(error), type = "error", duration = NULL))
    })

    output$upload_status <- shiny::renderUI(shiny::div(class = "text-muted", upload_message()))
    output$returns_table <- shiny::renderDataTable(returns(), options = list(pageLength = 10))
    output$metadata_table <- shiny::renderDataTable(metadata(), options = list(pageLength = 10))
    output$weights_table <- shiny::renderDataTable(weights(), options = list(pageLength = 10))
    output$attribution_table <- shiny::renderDataTable({
      shiny::req(results())
      data <- results()
      numeric <- vapply(data, is.numeric, logical(1))
      data[numeric] <- lapply(data[numeric], round, 6)
      data
    }, options = list(pageLength = 20, scrollX = TRUE))
    output$result_title <- shiny::renderText(paste(input$portfolio_name, "vs.", input$benchmark_name))
    output$download_results <- shiny::downloadHandler(
      filename = function() paste0("brinson-attribution-", Sys.Date(), ".csv"),
      content = function(file) utils::write.csv(results(), file, row.names = FALSE)
    )
  })
}
