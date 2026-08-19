mod_attribution_ui <- function(id) {
  ns <- shiny::NS(id)

  bslib::navset_card_tab(
    title = "Brinson workflow",
    bslib::nav_panel(
      "1. Returns",
      bslib::layout_columns(
        col_widths = c(4, 8),
        bslib::card(
          bslib::card_header("Upload price series"),
          shiny::fileInput(ns("return_file"), "Excel workbook", accept = ".xlsx"),
          shiny::helpText(paste(
            "Wide format: the first two columns contain ticker and name;",
            "all following column headers are Excel serial dates and their values are prices.",
            "Period returns are calculated automatically."
          )),
          shiny::uiOutput(ns("upload_status"))
        ),
        bslib::card(
          bslib::card_header("Imported observations"),
          DT::DTOutput(ns("returns_table"))
        )
      )
    ),
    bslib::nav_panel(
      "2. Metadata",
      bslib::layout_columns(
        col_widths = c(4, 8),
        bslib::card(
          bslib::card_header("Edit instrument metadata"),
          shiny::selectInput(ns("meta_ticker"), "Ticker", choices = NULL),
          shiny::textInput(ns("meta_name"), "Display name"),
          shiny::selectInput(ns("instrument_type"), "Series type",
            c("Asset" = "asset", "Currency / FX" = "currency")),
          shiny::textInput(ns("asset_class"), "Asset class"),
          shiny::textInput(ns("currency"), "Currency / FX exposure", value = "BASE"),
          shiny::selectInput(ns("return_type"), "Return convention",
            c("Simple return" = "simple", "Log return" = "log")),
          shiny::checkboxInput(ns("enabled"), "Include series", TRUE),
          shiny::actionButton(ns("save_metadata"), "Save metadata", class = "btn-primary")
        ),
        bslib::card(
          bslib::card_header("Metadata catalogue"),
          DT::DTOutput(ns("metadata_table"))
        )
      )
    ),
    bslib::nav_panel(
      "3. Portfolios",
      bslib::layout_columns(
        col_widths = c(4, 8),
        bslib::card(
          bslib::card_header("Portfolio and composite benchmark"),
          shiny::textInput(ns("portfolio_name"), "Portfolio name", "Portfolio"),
          shiny::textInput(ns("benchmark_name"), "Composite benchmark name", "Policy benchmark"),
          shiny::selectInput(ns("weight_ticker"), "Asset", choices = NULL),
          shiny::numericInput(ns("portfolio_weight"), "Portfolio weight", 0, min = 0, step = 0.01),
          shiny::numericInput(ns("benchmark_weight"), "Benchmark weight", 0, min = 0, step = 0.01),
          shiny::actionButton(ns("save_weight"), "Set weights", class = "btn-primary"),
          shiny::actionButton(ns("equal_weights"), "Initialize equal weights")
        ),
        bslib::card(
          bslib::card_header("Definition (normalized when calculated)"),
          DT::DTOutput(ns("weights_table"))
        )
      )
    ),
    bslib::nav_panel(
      "4. Attribution",
      bslib::layout_columns(
        col_widths = c(4, 8),
        bslib::card(
          bslib::card_header("Calculation settings"),
          shiny::dateRangeInput(ns("date_range"), "Start and end"),
          shiny::selectInput(ns("frequency"), "Rebalancing / attribution period",
            c("Monthly", "Quarterly", "Yearly", "Daily", "Full horizon")),
          shiny::textInput(ns("base_currency"), "Base currency", "BASE"),
          shiny::helpText("Asset returns stay local. FX series are linked separately and reported as a currency effect."),
          shiny::actionButton(ns("calculate"), "Run Brinson decomposition", class = "btn-success")
        ),
        bslib::card(
          bslib::card_header(shiny::textOutput(ns("result_title"), inline = TRUE)),
          DT::DTOutput(ns("attribution_table")),
          shiny::downloadButton(ns("download_results"), "Download results")
        )
      )
    )
  )
}
