library(shiny)
library(bslib)

source("R/brinson.R")
source("R/mod_attribution_ui.R")
source("R/mod_attribution_server.R")

ui <- page_fillable(
  title = "TAA Attribution",
  theme = bs_theme(
    version = 5,
    bootswatch = "cosmo",
    primary = "#0d6efd"
  ),
  shiny::tags$header(
    class = paste(
      "container-fluid border-bottom bg-body-tertiary",
      "px-4 py-3 flex-shrink-0"
    ),
    shiny::tags$h1(
      class = "h3 mb-1",
      "TAA Attribution"
    ),
    shiny::tags$p(
      class = "text-muted mb-0",
      "Exploration workspace"
    )
  ),
  mod_attribution_ui("attribution")
)

server <- function(input, output, session) {
  mod_attribution_server("attribution")
}

shinyApp(ui, server)
