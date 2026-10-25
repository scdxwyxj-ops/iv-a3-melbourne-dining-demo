# Offline tests for the ACTIVE OSM server; no Google request is issued.
source("R/domain.R")
source("R/osm_server.R")
landmarks <- read.csv("data/landmarks.csv", stringsAsFactors = FALSE)
config <- list(browser_key = "TEST_BROWSER_ONLY", request_limit = 2L)
n <- 0L
check <- function(ok, label) { if (!isTRUE(ok)) stop(label); n <<- n + 1L; cat("PASS", label, "\n") }
shiny::testServer(create_osm_server(config, landmarks), {
  messages <- list()
  session$sendCustomMessage <- function(type, message) { messages[[length(messages) + 1L]] <<- list(type = type, value = message) }
  session$setInputs(client_ready = 1, search = 0, radius = "600", cuisine = "", places_status = "ready")
  check(calls() == 0, "No automatic restaurant search")
  init <- Filter(function(x) x$type == "osm-init", messages)[[1]]$value
  check(length(init$landmarks) == 242 && !"serverKey" %in% names(init), "242 landmarks; no server key")
  session$setInputs(search = 1)
  check(calls() == 0, "Missing landmark prevents search")
  session$setInputs(landmark = landmarks$landmark_id[1], radius = "-2", cuisine = "invalid")
  check(scene()$radius == 600 && scene()$cuisine == "", "Invalid search parameters normalized")
  session$setInputs(sort = "rating")
  check(scene()$rankPreference == "DISTANCE", "Unsupported old rating sort rejected")
  distance_key <- scene()$key
  session$setInputs(sort = "POPULARITY")
  check(scene()$rankPreference == "DISTANCE" && scene()$key == distance_key && calls() == 0,
    "Removed popularity input cannot change fixed distance ranking")
  for (value in c(200, 650, 1200)) {
    session$setInputs(radius = value)
    check(scene()$radius == value, paste("Slider radius accepted:", value))
  }
  for (value in c(199, 1201, 625, NA_real_)) {
    session$setInputs(radius = value)
    check(scene()$radius == 600, paste("Invalid slider radius rejected:", value))
  }
  session$setInputs(radius = "300", cuisine = "japanese_restaurant", search = 2)
  check(calls() == 1, "Explicit valid search dispatched")
  search_message <- tail(Filter(function(x) x$type == "osm-search", messages), 1)[[1]]$value
  check(search_message$radius == 300 && search_message$cuisine == "japanese_restaurant", "Radius and cuisine propagated")
  check(search_message$rankPreference == "DISTANCE", "Search request always uses distance ranking")
  session$setInputs(radius = "1000")
  check(calls() == 1, "Changing radius does not issue billable search")
  session$setInputs(search = 3)
  check(calls() == 1, "Rapid repeat throttled")
  last_call(Sys.time() - 4)
  session$setInputs(search = 4)
  check(calls() == 2, "Second deliberate search dispatched")
  last_call(Sys.time() - 4)
  session$setInputs(search = 5)
  check(calls() == 2, "Session search limit enforced")
  session$setInputs(landmark = "invalid")
  check(is.null(scene()$landmark), "Unknown landmark rejected")
})
shiny::testServer(create_osm_server(list(browser_key = "", request_limit = 2L), landmarks), {
  session$setInputs(search = 0, landmark = landmarks$landmark_id[1], places_status = "ready")
  session$setInputs(search = 1)
  check(calls() == 0, "Missing browser key blocks searches")
})
cat(n, "active OSM server checks passed.\n")
