compare_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$landmark_a, { req(input$landmark_a %in% data$landmarks$poi_id); state$comparison_a_id <- input$landmark_a })
    observeEvent(input$landmark_b, { req(input$landmark_b %in% data$landmarks$poi_id); state$comparison_b_id <- input$landmark_b })
    observeEvent(input$radius, { req(is.finite(input$radius)); state$comparison_radius_m <- input$radius })
    output$counts <- renderUI({
      a <- venues_near(data, state$comparison_a_id, state$comparison_radius_m)
      b <- venues_near(data, state$comparison_b_id, state$comparison_radius_m)
      tagList(div(class = "comparison-metrics", metric_card(nrow(a), "Landmark A"), metric_card(nrow(b), "Landmark B", tone = "secondary")),
        metric_card(length(intersect(a$venue_id, b$venue_id)), "venues in both catchments", "Data preview · map and category chart pending", tone = "secondary"))
    })
    # TODO owner: synchronized map and grouped category chart; stable overlap IDs.
  })
}
