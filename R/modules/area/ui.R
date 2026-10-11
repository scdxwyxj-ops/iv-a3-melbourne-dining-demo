area_ui <- function(id, data) {
  ns <- NS(id)
  tagList(
    feature_heading("Where to eat across Melbourne", "Compare dining options across the City's CLUE areas."),
    div(class = "feature-layout area-layout",
      panel_card("Explore an area", class = "control-panel",
        selectInput(ns("area"), "CLUE area", choices = data$areas, selected = "Carlton"),
        p(class = "help-copy", "Area boundaries describe CLUE statistical areas, not only the CBD."),
        next_step_note("Next: connect an area selection to the map and Tableau chart.")),
      panel_card("Area map", placeholder_canvas("CLUE boundary map placeholder", "Display the 13 boundaries and highlight the selected area."), category_legend()),
      panel_card("Dining overview", class = "summary-panel",
        uiOutput(ns("count")), tableau_placeholder())
    )
  )
}
