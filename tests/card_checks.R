source("tests/compare_checks.R")
testServer(compare_server, args = list(data = d, state = create_shared_state(d)), {
  session$setInputs(landmark_a = a, landmark_b = b, radius = 600, category = "all")
  ids <- result()$venues$venue_id
  session$setInputs(map_marker_click = list(id = ids[1]))
  stopifnot(identical(selected_id(), ids[1]), nrow(selected_venue()) == 1, length(output$venue_card) > 0)
  session$setInputs(card_toggle = 1); stopifnot(card_collapsed())
  session$setInputs(map_marker_click = list(id = ids[2])); stopifnot(!card_collapsed(), identical(selected_id(), ids[2]))
  session$setInputs(card_close = 1); stopifnot(is.null(selected_id()), nrow(selected_venue()) == 0)
  session$setInputs(map_marker_click = list(id = ids[1])); session$setInputs(radius = 300)
  stopifnot(is.null(selected_id()))
})
cat("PASS: corner card selection, switching, collapse, close and filter reset.\n")
