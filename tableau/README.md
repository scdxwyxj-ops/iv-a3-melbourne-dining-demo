# Tableau workbooks and integration

This directory is reserved for the area overview's Tableau workbook and publication details. The current version contains no workbook. The chart region provided by `R/core/tableau.R` remains a placeholder.

## Data and chart definitions

Connect the chart directly to `data/venues.csv` in the repository. Use `area` for the area field and `category` for dining categories. Venue counts use `COUNTD(venue_id)` and represent distinct venues within each CLUE area. Counts are not labelled as density.

Category colours match the Shiny interface; see the [shared design language](../docs/DESIGN_LANGUAGE.md).

## Shiny integration

The course requires the final Shiny application to include at least one Tableau visualisation. Integration methods are described in [GEOM90007 Week 8.5](https://canvas.lms.unimelb.edu.au/courses/241878/pages/8-dot-5-pre-lab-tasks-integrating-tableau-into-shiny). The course page requires the appropriate Canvas access.

Store workbook files in this directory. After publication, the integration notes should record the workbook filename, published URL, and author, along with the input data and chart filter fields. `R/core/tableau.R` is the Shiny integration location.

Workbooks published through Tableau Public are publicly accessible. See the [data documentation](../data/README.md) for attribution and licensing.

## Integration checks

- The Shiny page loads the actual workbook instead of a placeholder.
- The chart fits its card layout and remains visible after page navigation.
- Venue counts agree with `venues.csv`.
- If linked interactions are implemented, Shiny controls and Tableau filters use the same scope.
- Published content retains data sources and licence information.

Update the root README's feature status table when the Tableau chart or its integration status changes.
