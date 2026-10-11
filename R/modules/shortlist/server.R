shortlist_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    output$saved_count <- renderUI({ metric_card(length(state$saved_venue_ids), "saved venues", "Shortlist implementation pending") })
    # TODO owner: details, save/remove, export. Missing seating must display Unknown.
    # Never join by name or coordinates; use venue_id. Do not pre-populate favourites.
  })
}
