# TAA Attribution

Shiny dashboard for flexible, holdings-based Brinson attribution. Users supply only
return observations and then enrich each ticker inside the application.

## Return workbook

Upload an `.xlsx`, `.xls`, or `.csv` file containing one observation per ticker and
date. Column names are case-insensitive and must be:

| Column | Meaning |
|---|---|
| `ticker` | Stable, unique series identifier |
| `date` | Observation date (ISO date or an Excel date) |
| `name` | Initial display label; it can be changed in the app |
| `value` | Simple or logarithmic period return, expressed as a decimal |

The metadata step classifies each series as either an **asset** or **currency**
series. Assets receive a freely chosen asset-class label and a currency exposure.
Currency series use that exposure as their currency key. For example, a EUR asset
has `currency = EUR`, while an EUR/base FX return series has type `currency` and
also has `currency = EUR`. Base-currency assets use the configurable `BASE` key.

Keeping FX series separate avoids silently folding currency performance into asset
selection. For a foreign asset, the base return is calculated exactly as
`(1 + local return) * (1 + FX return) - 1`. A missing foreign-currency series is a
validation error rather than being treated as a zero return.

## Portfolio and benchmark definitions

The portfolio and composite benchmark are defined as ticker weights. Inputs do not
need to sum to one: the calculation normalizes each side independently. Weights must
be non-negative. The selected attribution frequency represents the rebalancing
frequency for these target weights. `Full horizon` applies one period to the entire
selected date range.

## Attribution model

For every asset class and period, the dashboard calculates the Brinson-Fachler
allocation, selection, and interaction effects using local asset returns. It then
adds a separate currency effect equal to portfolio currency contribution minus
benchmark currency contribution. The exported total effect is:

`allocation + selection + interaction + currency`.

Results are kept at period/asset-class level so that users can apply their preferred
multi-period linking method downstream without the dashboard hiding that choice.
