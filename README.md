# TAA Attribution

Shiny dashboard for flexible, holdings-based Brinson attribution. Users supply only
price observations and then enrich each ticker inside the application.

## Price workbook

Upload an `.xlsx` file in wide format. Each row represents one series. The first two
columns are interpreted as ticker and display name (their original headings do not
matter); every subsequent column heading must be a numeric Excel serial date.

| First column | Second column | Following columns |
|---|---|---|
| Stable, unique ticker | Initial display name | Prices under Excel serial-date headings |

The application sorts the dates for each ticker and calculates simple returns as
`current price / previous price - 1`. The first price therefore establishes the
base and does not produce a return. Blank prices are skipped; at least two observed
prices are needed for a ticker to produce a return.

The metadata step classifies each series as either an **asset** or **currency**
series. Assets receive a freely chosen asset-class label and one of the supported
currency codes. Currency series instead receive an explicit FX base/quote pair.

Keeping FX series separate avoids silently folding currency performance into asset
selection. For a foreign asset, the base return is calculated exactly as
`(1 + local return) * (1 + FX return) - 1`. A missing foreign-currency series is a
validation error rather than being treated as a zero return.

## Portfolio definitions

Every portfolio (including a benchmark) is defined in exactly the same way: a name,
a base currency (CHF, EUR, or USD), and ticker weights. In the attribution tab, two
saved portfolios are selected for comparison. Inputs do not need to sum to one; the
calculation normalizes each side independently. Rebalancing can follow a daily,
weekly, monthly, quarterly, or annual frequency, or a list of specific dates.

## Currency convention

Assets carry their local currency. Each FX series explicitly records a base and a
quote currency: `EUR / USD` means USD per one EUR. For a USD portfolio, this series
therefore converts EUR assets directly; for an EUR portfolio, the application
inverts its return. Comparisons currently require both portfolios to share one of
the supported base currencies (CHF, EUR, USD). This explicit pair direction is also
the foundation for a later currency-allocation decomposition.

## Persistence and backups

Returns, metadata, portfolios, and specific rebalancing dates are stored in a local
SQLite database (`data/taa-attribution.sqlite` by default). The Data & backup tab
can download the database as one portable backup and restore a previously downloaded
SQLite file.

## Attribution model

For every asset class and period, the dashboard calculates the Brinson-Fachler
allocation, selection, and interaction effects using local asset returns. It then
adds a separate currency effect equal to portfolio currency contribution minus
benchmark currency contribution. The exported total effect is:

`allocation + selection + interaction + currency`.

Results are kept at period/asset-class level so that users can apply their preferred
multi-period linking method downstream without the dashboard hiding that choice.
