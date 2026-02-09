mod_attribution_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::tagList(
    bslib::layout_columns(
      col_widths = c(4, 8),
      bslib::card(
        bslib::card_header("Filters"),
        shiny::selectInput(ns("saa"), "SAA", choices = NULL),
        shiny::selectInput(ns("taa"), "TAA", choices = NULL),
        shiny::dateRangeInput(ns("date_range"), "Date range")
      ),
      bslib::card(
        bslib::card_header("Attribution"),
        shiny::div(
          class = "text-muted",
          "Placeholder for attribution outputs."
        )
      )
    )
  )
}
