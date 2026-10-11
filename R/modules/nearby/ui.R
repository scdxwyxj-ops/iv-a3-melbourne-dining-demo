nearby_ui <- function(id, data) {
  ns <- NS(id)
  choices <- landmark_choices(data)
  tagList(
    feature_heading("Find dining near a landmark", "Explore dining choices within a straight-line radius.", "Owner · Jun Xu"),
    div(class = "feature-layout nearby-layout",
      panel_card("Choose a starting point", class = "control-panel",
        selectInput(ns("landmark"), "Landmark", choices = choices, selected = unname(choices[["Federation Square"]])),
        sliderInput(ns("radius"), "Radius (metres)", min = 200, max = 1200, value = 600, step = 100),
        p(class = "help-copy", "Distances use recorded coordinates. They are not walking routes."),
        next_step_note("Next: draw the selected landmark, radius and dining points. Add a selectable venue list.")),
      panel_card("Nearby map", placeholder_canvas("Landmark and radius map placeholder", "Link the chosen landmark and radius to dining markers."), category_legend()),
      panel_card("Nearby dining", class = "summary-panel",
        uiOutput(ns("count")),
        div(class = "list-placeholder", h3("Venue list placeholder"), p("Show nearby venues ordered by straight-line distance.")))
    )
  )
}
