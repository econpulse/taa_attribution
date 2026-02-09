library(shiny)
library(bslib)

source("R/mod_attribution_ui.R")
source("R/mod_attribution_server.R")

ui <- page_fillable(
  title = "TAA Attribution",
  theme = bs_theme(
    version = 5,
    bootswatch = "cosmo",
    primary = "#0d6efd"
  ),
  bslib::page_header(
    title = "TAA Attribution",
    subtitle = "Exploration workspace"
  ),
  mod_attribution_ui("attribution")
)

server <- function(input, output, session) {
  mod_attribution_server("attribution")
}

shinyApp(ui, server)
