area_venues <- function(data, area) {
  if (length(area) != 1L || !area %in% data$areas) stop('Unknown CLUE area')
  data$venues[data$venues$area == area, , drop = FALSE]
}

area_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    boundaries <- sf::st_read(jsonlite::toJSON(data$boundaries, auto_unbox=TRUE), quiet=TRUE)
    boundaries <- sf::st_transform(boundaries, 4326)
    observeEvent(input$area, { req(input$area %in% data$areas); state$area <- input$area })
    observeEvent(input$map_shape_click, {
      area <- input$map_shape_click$id
      req(area %in% data$areas)
      state$area <- area
      updateSelectInput(session, 'area', selected=area)
    })
    selected_venues <- reactive(area_venues(data, state$area))
    observeEvent(state$area, {
      updateSelectInput(session, 'area', selected=state$area)
    })
    output$map <- leaflet::renderLeaflet({
      box <- sf::st_bbox(boundaries)
      map <- leaflet::leaflet(options=leaflet::leafletOptions(preferCanvas=TRUE))
      map <- leaflet::addTiles(map)
      map <- leaflet::addPolygons(map, data=boundaries, layerId=~featurenam,
        color='#657970', weight=1, fillColor='#dce6e0', fillOpacity=0.25,
        label=~featurenam, highlightOptions=leaflet::highlightOptions(weight=3, bringToFront=TRUE))
      leaflet::fitBounds(map, box[['xmin']], box[['ymin']], box[['xmax']], box[['ymax']])
    })
    observe({
      venues <- selected_venues()
      selected <- boundaries[boundaries$featurenam == state$area, ]
      map <- leaflet::leafletProxy('map', session=session)
      map <- leaflet::clearGroup(map, 'selection')
      map <- leaflet::clearGroup(map, 'venues')
      map <- leaflet::addPolygons(map, data=selected, group='selection', layerId=~featurenam,
        color='#087f80', weight=3, fillColor='#087f80', fillOpacity=0.12)
      escape <- function(x) as.character(htmltools::htmlEscape(ifelse(is.na(x), 'Unknown', x)))
      popups <- paste0('<strong>', escape(venues$name), '</strong><br>',
                       escape(venues$category), '<br>', escape(venues$address))
      colors <- ifelse(venues$category == 'Takeaway', '#db8950', '#087f80')
      leaflet::addCircleMarkers(map, lng=venues$longitude, lat=venues$latitude,
        group='venues', layerId=venues$venue_id, radius=5, weight=1, color='white',
        fillColor=colors, fillOpacity=0.85, popup=popups,
        clusterOptions=leaflet::markerClusterOptions())
    })
    observeEvent(state$area, {
      box <- sf::st_bbox(boundaries[boundaries$featurenam == state$area, ])
      leaflet::fitBounds(leaflet::leafletProxy('map', session=session),
        box[['xmin']], box[['ymin']], box[['xmax']], box[['ymax']])
    }, ignoreInit=TRUE)
    observeEvent(input$reset_map, {
      box <- sf::st_bbox(boundaries)
      leaflet::fitBounds(leaflet::leafletProxy('map', session=session),
        box[['xmin']], box[['ymin']], box[['xmax']], box[['ymax']])
    })
    output$count <- renderUI({
      metric_card(nrow(selected_venues()), paste("venues in", state$area), "2024 census · not live availability")
    })
    output$map_title <- renderText(paste('Dining in', state$area))
  })
}
