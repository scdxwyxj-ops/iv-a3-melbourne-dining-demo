create_shared_state <- function(data) {
  # Call once inside the Shiny server. ID fields always refer to committed data.
  choices <- landmark_choices(data)
  shiny::reactiveValues(
    area = "Carlton",
    landmark_id = unname(choices[["Federation Square"]]),
    radius_m = 600,
    comparison_a_id = unname(choices[["Federation Square"]]),
    comparison_b_id = unname(choices[["State Library Victoria"]]),
    comparison_radius_m = 600,
    selected_venue_id = NULL,
    saved_venue_ids = character(0)
  )
}
