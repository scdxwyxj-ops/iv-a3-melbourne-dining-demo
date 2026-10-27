area_venues <- function(data, area) {
  core_venues(data, area = area)
}
area_server <- function(id, data, state) {
  moduleServer(
    id,
    function(input, output, session) {
      selected_venues <- reactive(area_venues(data, state$area))
      observeEvent(
        input$area,
        {
          req(input$area %in% data$areas)
          state$area <- input$area
        }
      )
      observeEvent(
        input$map_shape_click,
        {
          area <- input$map_shape_click$id
          req(area %in% data$areas)
          state$area <- area
          updateSelectInput(session, "area", selected = area)
        }
      )
      observeEvent(
        state$area,
        {
          updateSelectInput(session, "area", selected = state$area)
        }
      )
      observeEvent(
        input$map_marker_click,
        {
          id <- input$map_marker_click$id
          req(id %in% selected_venues()$venue_id)
          state$selected_venue_id <- id
        }
      )
      map_scene <- reactive({
        venues <- selected_venues()
        features <- core_boundaries(data)$features
        for (i in seq_along(features)) {
          features[[i]]$properties$core_selected <- identical(
            features[[i]]$properties$featurenam,
            state$area
          )
        }
        selected <- Filter(
          function(f) identical(f$properties$featurenam, state$area),
          features
        )
        markers <- core_venue_markers(venues, cluster = TRUE, popup = TRUE)
        list(
          scope = state$area,
          boundaries = list(type = "FeatureCollection", features = features),
          markers = markers,
          bounds = core_geo_bounds(selected),
          selected = state$selected_venue_id
        )
      })
      observe({
        req(isTRUE(input$map_ready))
        core_map_render(session, "map", map_scene())
      })
      observeEvent(
        input$reset_map,
        {
          core_map_fit(
            session,
            "map",
            core_geo_bounds(core_boundaries(data)$features)
          )
        }
      )
      output$count <- renderUI({
        metric_card(
          nrow(selected_venues()),
          paste("venues in", state$area),
          "2024 census · 2024 seating census"
        )
      })
      output$map_title <- renderText(paste("Dining in", state$area))
    }
  )
}
