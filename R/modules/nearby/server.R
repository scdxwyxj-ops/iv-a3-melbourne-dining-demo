# Feature 2 owns nearby settings and venue selection; feature 4 owns saved IDs.
nearby_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$landmark, {
      req(length(input$landmark) == 1L, input$landmark %in% data$landmarks$poi_id)
      state$landmark_id <- input$landmark
    })
    observeEvent(input$radius, {
      req(length(input$radius) == 1L, is.finite(input$radius), input$radius >= 200, input$radius <= 1200)
      state$radius_m <- input$radius
    })
    nearby_venues <- reactive({ venues_near(data, state$landmark_id, state$radius_m) })

    # Clear a selection only when a changed catchment no longer contains it.
    observeEvent(nearby_venues(), {
      if (!is.null(state$selected_venue_id) && !state$selected_venue_id %in% nearby_venues()$venue_id) {
        state$selected_venue_id <- NULL
      }
    })
    observeEvent(input$select_venue, {
      selected <- input$select_venue
      req(is.character(selected), length(selected) == 1L, selected %in% nearby_venues()$venue_id)
      state$selected_venue_id <- selected
    })
    observeEvent(input$clear_selection, { state$selected_venue_id <- NULL })

    output$count <- renderUI({
      venues <- nearby_venues()
      tagList(
        metric_card(nrow(venues), paste("venues within", state$radius_m, "m"), "Straight-line distance · 2024 census"),
        div(class = "nearby-category-counts",
          div(strong(sum(venues$category_code == "4511")), span("Cafés & restaurants")),
          div(strong(sum(venues$category_code == "4512")), span("Takeaway")))
      )
    })
    output$map_caption <- renderUI({
      origin <- get_landmark(data, state$landmark_id)
      p(class = "nearby-map-caption", strong(origin$name), span(paste(" ·", state$radius_m, "m radius")))
    })
    output$list <- renderUI({
      venues <- nearby_venues()
      if (!nrow(venues)) {
        return(div(class = "nearby-empty", h3("No venues within this radius"),
          p("Increase the radius or choose another landmark.")))
      }
      tagList(lapply(seq_len(nrow(venues)), function(i) {
        venue <- venues[i, ]
        tags$button(type = "button", class = "nearby-venue", `data-venue-id` = venue$venue_id,
          `aria-pressed` = "false",
          span(class = "nearby-venue-top", strong(class = "nearby-venue-name", venue$name),
            span(class = "nearby-distance", paste(round(venue$distance_m), "m"))),
          span(class = "nearby-venue-category",
            span(class = paste("legend-dot", if (venue$category_code == "4512") "takeaway" else "cafe")), venue$category),
          span(class = "nearby-venue-address", venue$address))
      }))
    })
    output$selection <- renderUI({
      selected <- state$selected_venue_id
      venues <- nearby_venues()
      venue <- venues[venues$venue_id %in% selected, , drop = FALSE]
      if (nrow(venue) != 1L) {
        return(p(class = "help-copy", "Select a map marker or a venue in the list to highlight it."))
      }
      tagList(
        strong(class = "nearby-selected-name", venue$name),
        p(class = "nearby-selected-meta", venue$category),
        p(class = "help-copy", venue$address),
        p(class = "nearby-selected-distance", paste(round(venue$distance_m), "m from the landmark")),
        actionButton(session$ns("clear_selection"), "Clear selection", class = "btn-default nearby-clear")
      )
    })

    # Message types and input IDs are namespaced, keeping this browser adapter local.
    observe({
      req(isTRUE(input$map_ready))
      origin <- get_landmark(data, state$landmark_id)
      venues <- nearby_venues()
      fields <- c("venue_id", "name", "category", "category_code", "longitude", "latitude", "distance_m")
      rows <- lapply(seq_len(nrow(venues)), function(i) as.list(venues[i, fields, drop = FALSE]))
      session$sendCustomMessage(session$ns("map_update"), list(
        scope = paste(state$landmark_id, state$radius_m, sep = ":"),
        origin = list(name = origin$name, longitude = origin$longitude, latitude = origin$latitude),
        radius = state$radius_m, venues = rows, selected = state$selected_venue_id
      ))
    })
  })
}
