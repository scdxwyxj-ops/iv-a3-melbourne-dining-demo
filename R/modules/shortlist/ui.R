shortlist_ui <- function(id, data) {
  ns <- NS(id)
  tagList(
    feature_heading("Place details and your shortlist", "Review one venue and save places to compare later."),
    div(class = "feature-layout shortlist-layout",
      panel_card("Venue details", class = "detail-panel",
        div(class = "list-placeholder", h3("Select a venue"), p("Feature 2 will pass a venue ID here. Display its name, address, category and recorded seating.")),
        tags$button(type = "button", class = "btn btn-primary", disabled = "disabled", "Save venue · coming next"),
        next_step_note("Next: read selected_venue_id and manage saved_venue_ids using the shared state.")),
      panel_card("Selected venue map", placeholder_canvas("Venue location placeholder", "Highlight the selected venue and retain its landmark context.")),
      panel_card("Your shortlist", class = "summary-panel", uiOutput(ns("saved_count")),
        p(class = "help-copy", "No demo favourites have been pre-saved."),
        tags$button(type = "button", class = "btn btn-default", disabled = "disabled", "Export CSV · coming next"))
    )
  )
}
