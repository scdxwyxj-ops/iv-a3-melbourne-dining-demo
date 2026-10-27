# Public map boundary: feature modules supply data/events, core owns rendering.
core_map_dependencies <- function() {
  shiny::tags$head(
    shiny::tags$script(shiny::HTML(paste0(
      "window.DiningConfig = ",
      jsonlite::toJSON(public_browser_settings(), auto_unbox = TRUE),
      ";"
    ))),
    shiny::tags$link(
      rel = "stylesheet",
      href = "core-map/vendor/leaflet/leaflet.css"
    ),
    shiny::tags$link(
      rel = "stylesheet",
      href = "core-map/vendor/markercluster/MarkerCluster.css"
    ),
    shiny::tags$link(rel = "stylesheet", href = "core-map/maps.css?v=4.6"),
    shiny::tags$script(src = "core-map/vendor/leaflet/leaflet.js"),
    shiny::tags$script(
      src = "core-map/vendor/markercluster/leaflet.markercluster.js"
    ),
    shiny::tags$script(src = "core-map/maps.js?v=4.6")
  )
}

core_map_ui <- function(id, height = "580px", label = "Dining map") {
  shiny::div(
    id = id,
    class = "core-map",
    style = paste0("height:", height, ";width:100%;"),
    role = "region",
    `aria-label` = label,
    `data-core-map-mode` = "scene"
  )
}

core_map_render <- function(session, id, scene) {
  session$sendCustomMessage(
    "core-map-render",
    c(
      list(id = session$ns(id)),
      scene
    )
  )
}

core_map_fit <- function(session, id, bounds) {
  session$sendCustomMessage(
    "core-map-fit",
    list(
      id = session$ns(id),
      bounds = bounds
    )
  )
}

core_geo_bounds <- function(features) {
  coordinates <- unlist(
    lapply(features, function(feature) feature$geometry$coordinates),
    use.names = FALSE
  )
  points <- matrix(coordinates, ncol = 2L, byrow = TRUE)
  list(
    c(
      min(points[, 2]),
      min(points[, 1])
    ),
    c(
      max(points[, 2]),
      max(points[, 1])
    )
  )
}

core_map_rows <- function(data, fields = names(data)) {
  lapply(
    seq_len(nrow(data)),
    function(i) as.list(data[i, fields, drop = FALSE])
  )
}

core_venue_markers <- function(
  venues,
  cluster = FALSE,
  popup = FALSE,
  colour_by = c("category", "catchment")
) {
  colour_by <- match.arg(colour_by)
  if (colour_by == "catchment") {
    require_columns(venues, "membership", "Catchment marker data")
    if (!all(venues$membership %in% c("a", "b", "shared"))) {
      stop("Use a, b or shared catchment membership.")
    }
  }
  lapply(
    seq_len(nrow(venues)),
    function(i) {
      v <- venues[i, ]
      marker <- list(
        id = v$venue_id,
        latitude = v$latitude,
        longitude = v$longitude,
        title = v$name,
        role = "venue",
        category_code = v$category_code,
        address = v$address,
        layer = "venues",
        cluster = cluster,
        colour_by = colour_by
      )
      if (colour_by == "catchment") {
        marker$membership <- v$membership
      }
      if (popup) {
        marker$popup <- list(v$category, v$address)
      }
      marker
    }
  )
}
