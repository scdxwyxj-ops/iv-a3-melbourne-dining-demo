create_shared_state <- function(data) {
  # Call once inside the Shiny server. ID fields always refer to committed data.
  choices <- landmark_choices(data)
  shiny::reactiveValues(
    area = app_settings()$defaults$area,
    landmark_id = unname(choices[[app_settings()$defaults$nearby_landmark]]),
    radius_m = app_settings()$nearby$radius_default_m,
    comparison_a_id = unname(choices[[app_settings()$defaults$comparison_a]]),
    comparison_b_id = unname(choices[[app_settings()$defaults$comparison_b]]),
    comparison_radius_m = app_settings()$compare$radius_default_m,
    selected_venue_id = NULL
  )
}
