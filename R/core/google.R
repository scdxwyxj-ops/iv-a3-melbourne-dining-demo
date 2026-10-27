# Restaurant details use Google Places UI Kit and the shared runtime settings.
core_google_config <- function() {
  config <- app_settings()$google
  list(
    browser_key = config$browser_key,
    request_limit = as.integer(config$request_limit)
  )
}

core_google_dependencies <- function() {
  tags$head(tags$script(src = "core-google/details.js?v=4.6"))
}

core_google_detail_ui <- function(venue, config) {
  payload <- list(
    venue_id = venue$venue_id,
    name = venue$name,
    address = venue$address,
    latitude = venue$latitude,
    longitude = venue$longitude,
    browser_key = config$browser_key,
    request_limit = config$request_limit
  )
  div(
    class = "google-venue-details",
    `data-google-config` = jsonlite::toJSON(payload, auto_unbox = TRUE),
    p(
      class = "google-detail-status",
      role = "status",
      "Live Google details load when this window opens."
    ),
    div(
      class = "google-match-heading",
      hidden = "hidden",
      h4("Confirm the matching restaurant"),
      p(
        "Choose the Google listing with the matching name and address."
      )
    ),
    div(class = "google-place-host"),
    div(
      class = "google-detail-actions",
      tags$button(
        type = "button",
        class = "btn btn-default google-retry",
        hidden = "hidden",
        "Retry Google query"
      ),
      tags$a(
        class = "google-maps-link",
        href = paste0(
          "https://www.google.com/maps/search/?api=1&query=",
          utils::URLencode(
            paste(venue$name, venue$address),
            reserved = TRUE
          )
        ),
        target = "_blank",
        rel = "noopener noreferrer",
        "Search on Google Maps"
      )
    ),
    p(
      class = "venue-note",
      "Google supplies the restaurant details."
    )
  )
}
