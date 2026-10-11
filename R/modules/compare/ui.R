compare_ui <- function(id, data) {
  ns <- NS(id)
  choices <- landmark_choices(data)
  tagList(
    feature_heading("Compare two places", "Use the same radius and dining categories for both landmarks."),
    div(class = "feature-layout compare-layout",
      panel_card("Compare settings", class = "control-panel",
        selectInput(ns("landmark_a"), "Landmark A", choices, selected = unname(choices[["Federation Square"]])),
        selectInput(ns("landmark_b"), "Landmark B", choices, selected = unname(choices[["State Library Victoria"]])),
        sliderInput(ns("radius"), "Shared radius (metres)", min = 200, max = 1200, value = 600, step = 100),
        next_step_note("Next: show both catchments, matching category bars and the overlap.")),
      panel_card("Comparison map", placeholder_canvas("Two-landmark map placeholder", "Use teal for A and purple for B. Show overlapping catchments explicitly.")),
      panel_card("Same-scope comparison", class = "summary-panel", uiOutput(ns("counts")),
        div(class = "list-placeholder", h3("Category chart placeholder"), p("Keep category ordering and count scales consistent between A and B.")))
    )
  )
}
