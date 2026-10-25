library(shiny)
for (f in c("data", "geo", "state", "components")) source(file.path("R/core", paste0(f, ".R")))
source("R/modules/compare/server.R")
source("R/modules/compare/ui.R")
d <- load_app_data("data")
ids <- unname(landmark_choices(d)); a <- ids[1]; b <- ids[2]
r <- compare_results(d, a, b, 600)
stopifnot(nrow(r$a) == 303, nrow(r$b) == 619, length(r$shared) == 65, nrow(r$venues) == 857)
for (radius in c(200, 600, 1200)) for (category in c("all", "4511", "4512")) {
  r <- compare_results(d, a, b, radius, category)
  stopifnot(!anyDuplicated(r$venues$venue_id), nrow(r$venues) == nrow(r$a) + nrow(r$b) - length(r$shared))
  if (category != "all") stopifnot(all(r$venues$category_code == category))
}
same <- compare_results(d, a, a, 600)
stopifnot(length(same$shared) == nrow(same$a), all(same$venues$membership == "shared"))
empty <- d; empty$venues <- d$venues[FALSE, ]
stopifnot(nrow(compare_results(empty, a, b, 600)$venues) == 0)
s <- create_shared_state(d)
testServer(compare_server, args = list(data = d, state = s), {
  session$setInputs(landmark_a = a, landmark_b = b, radius = 600, category = "all", scope = "shared")
  stopifnot(nrow(result()$a) == 303, nrow(listed()) == 65)
  stopifnot(nzchar(output$map), nzchar(output$venues), length(output$chart) > 0, length(output$counts) > 0)
  selected <- listed()$venue_id[1]
  session$setInputs(venue = selected, select_venue = 1)
  stopifnot(s$selected_venue_id == selected, s$radius_m == 600, length(s$saved_venue_ids) == 0)
  session$setInputs(radius = 200, category = "4512", scope = "all")
  stopifnot(all(result()$venues$category_code == "4512"), s$radius_m == 600)
  session$setInputs(landmark_b = a, category = "all", radius = 600)
  stopifnot(nrow(result()$a) == length(result()$shared), length(output$notice) > 0)
})
testServer(compare_server, args = list(data = empty, state = create_shared_state(d)), {
  session$setInputs(landmark_a = a, landmark_b = b, radius = 600, category = "all", scope = "shared")
  stopifnot(nrow(listed()) == 0, nzchar(output$map), length(output$chart) > 0)
})
stopifnot(inherits(compare_ui("compare", d), "shiny.tag"))
cat("PASS: reference counts, scope, overlap, same origin, empty results, reactive outputs and selection.\n")
