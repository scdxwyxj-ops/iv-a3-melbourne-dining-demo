# Feature 2 owner: Jun Xu. Work primarily in this directory and www/css/nearby.css.
nearby_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$landmark, { req(input$landmark %in% data$landmarks$poi_id); state$landmark_id <- input$landmark })
    observeEvent(input$radius, { req(is.finite(input$radius)); state$radius_m <- input$radius })
    nearby_venues <- reactive({ venues_near(data, state$landmark_id, state$radius_m) })
    output$count <- renderUI({
      metric_card(nrow(nearby_venues()), paste("venues within", state$radius_m, "m"), "Data preview · map and list pending")
    })
    # TODO Jun: use nearby_venues() for map/list and set state$selected_venue_id
    # when a user chooses a venue. Feature 4 owns adding/removing saved IDs.
  })
}
