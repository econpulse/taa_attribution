mod_attribution_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    dataset <- shiny::reactive({
      # Placeholder for dataset loading.
      # Replace with actual data ingest (e.g., readr::read_csv).
      data.frame(
        saa = character(),
        taa = character(),
        date = as.Date(character()),
        stringsAsFactors = FALSE
      )
    })

    taa_dates <- shiny::reactive({
      data <- dataset()
      if (nrow(data) == 0L) {
        return(NULL)
      }
      range(data$date, na.rm = TRUE)
    })

    shiny::observe({
      data <- dataset()

      shiny::updateSelectInput(
        session,
        "saa",
        choices = sort(unique(data$saa)),
        selected = NULL
      )
      shiny::updateSelectInput(
        session,
        "taa",
        choices = sort(unique(data$taa)),
        selected = NULL
      )
    })

    shiny::observe({
      date_range <- taa_dates()
      if (is.null(date_range)) {
        return()
      }

      shiny::updateDateRangeInput(
        session,
        "date_range",
        start = date_range[1],
        end = date_range[2],
        min = date_range[1],
        max = date_range[2]
      )
    })
  })
}
