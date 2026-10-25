area_ui <- function(id, data) {
  ns <- NS(id)
  tagList(
    div(class='feature-heading', div(h1('Where to eat across Melbourne'),
      p("Explore dining venues across the City's 13 CLUE areas."))),
    div(class = "feature-layout area-layout",
      panel_card("Explore an area", class = "control-panel",
        selectInput(ns("area"), NULL, choices = data$areas, selected = "Carlton"),
        p(class = "help-copy", "Area boundaries describe CLUE statistical areas, not only the CBD."),
        p(class='help-copy', 'Choose an area or click its boundary. Click a venue for its name and address.'),
        actionButton(ns('reset_map'), 'Reset map view')),
      panel_card(textOutput(ns('map_title'), inline=TRUE),
        leaflet::leafletOutput(ns('map'), height='580px'), category_legend(),
        p(class='help-copy', '2024 dining census. Numbered clusters group nearby markers; zoom in to explore individual venues.')),
      panel_card("Dining overview", class = "summary-panel",
        uiOutput(ns("count")), tableau_placeholder())
    )
  )
}
