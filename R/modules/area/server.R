area_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$area, { req(input$area %in% data$areas); state$area <- input$area })
    output$count <- renderUI({
      metric_card(sum(data$venues$area == state$area), paste("venues in", state$area), "Data preview · map and chart pending")
    })
    # TODO owner: Leaflet boundaries, area highlighting, actual Tableau integration.
  })
}
