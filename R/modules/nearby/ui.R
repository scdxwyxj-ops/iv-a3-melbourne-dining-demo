# Browser map: Leaflet 1.9.4 (https://leafletjs.com/reference.html), BSD-2-Clause.  Shiny owns
# filtering and shared state; this adapter handles map and list events.  Leaflet assets are bundled
# locally; OpenStreetMap tiles require internet.
nearby_ui <- function(id, data) {
  ns <- NS(id)
  choices <- landmark_choices(data)
  chart_layout <- nearby_chart_layout()
  landmark_search <- I("window.DiningNearby.initialiseLandmarkSearch")

  config <- jsonlite::toJSON(
    list(
      chart = chart_layout,
      root = ns("module"),
      map = ns("map"),
      status = ns("map_status"),
      list = ns("venues"),
      fit = ns("fit"),
      ready = ns("map_ready"),
      select = ns("select_venue"),
      message = ns("map_update"),
      reveal = ns("reveal_selection"),
      curveInput = ns("chart_radius"),
      curveOutput = ns("curve"),
      scatterOutput = ns("scatter"),
      radiusPreview = ns("radius_preview"),
      pointReadout = ns("point_readout"),
      pointChoices = ns("point_choices")
    ),
    auto_unbox = TRUE
  )
  tagList(
    tags$head(tags$script(src = "nearby/nearby.js?v=4.6")),
    div(
      id = ns("module"),
      class = "nearby-module",
      `data-nearby-config` = config,
      div(
        class = "feature-heading",
        div(
          h1("Find dining near a landmark"),
          p(
            "Browse every recorded venue nearby, inspect public details and explore distance and seating."
          )
        ),
        div(
          class = "feature-meta",
          span(
            class = "status-pill nearby-status",
            "Local results · live details on demand"
          )
        )
      ),
      div(
        class = "feature-layout nearby-layout",
        panel_card(
          "Choose a starting point",
          class = "control-panel",
          div(
            class = "nearby-landmark-picker",
            selectizeInput(
              ns("landmark"),
              "Landmark",
              choices = choices,
              selected = unname(choices[[
                app_settings()$defaults$nearby_landmark
              ]]),
              options = list(create = FALSE, onInitialize = landmark_search)
            )
          ),
          sliderInput(
            ns("radius"),
            "Radius (metres)",
            min = chart_layout$radius_min_m,
            max = chart_layout$radius_max_m,
            value = app_settings()$nearby$radius_default_m,
            step = chart_layout$radius_step_m
          ),
          p(
            class = "help-copy",
            "Distances use straight-line estimates from the landmark."
          ),
          div(
            class = "nearby-selection",
            h3("Selected venue"),
            uiOutput(ns("selection"))
          )
        ),
        div(
          class = "nearby-workspace",
          uiOutput(ns("count")),
          div(
            class = "nearby-view-tabs",
            tabsetPanel(
              id = ns("view"),
              type = "tabs",
              selected = "map",
              tabPanel(
                "Map & list",
                value = "map",
                div(
                  class = "nearby-map-layout",
                  panel_card(
                    "Nearby map",
                    class = "nearby-map-panel",
                    div(
                      class = "nearby-map-toolbar",
                      uiOutput(ns("map_caption")),
                      tags$button(
                        id = ns("fit"),
                        type = "button",
                        class = "btn btn-default nearby-fit",
                        "Fit search area"
                      )
                    ),
                    div(
                      class = "nearby-map-wrap",
                      div(
                        id = ns("map"),
                        class = "nearby-map core-map-adapter",
                        role = "region",
                        `aria-label` = "Map of dining venues around the selected landmark"
                      ),
                      p(
                        id = ns("map_status"),
                        class = "nearby-map-status",
                        role = "status",
                        "Loading map…"
                      )
                    ),
                    div(
                      class = "nearby-legend",
                      category_legend(),
                      span(
                        class = "nearby-origin-key",
                        span(`aria-hidden` = "true", "◆"),
                        "Selected landmark"
                      )
                    ),
                    p(
                      class = "nearby-map-note",
                      "Dining census · 2024. Numbered markers contain multiple venues at the same location."
                    )
                  ),
                  panel_card(
                    "Nearby dining",
                    class = "summary-panel nearby-results-panel",
                    p(
                      class = "nearby-list-caption",
                      "Nearest first · select a restaurant card"
                    ),
                    p(
                      class = "nearby-offline-note",
                      "Cards use the 2024 census and OSM snapshot. Full details loads Google information on demand."
                    ),
                    div(
                      id = ns("venues"),
                      class = "nearby-list",
                      `aria-label` = "Nearby dining results",
                      uiOutput(ns("list"))
                    )
                  )
                )
              ),
              tabPanel(
                "Radius options",
                value = "radius",
                panel_card(
                  "How many options within a larger radius?",
                  class = "nearby-analysis-card",
                  p(
                    id = ns("curve_hint"),
                    class = "nearby-chart-intro",
                    "Click the curve to set a radius. Arrow keys adjust it by 100 m."
                  ),
                  p(
                    class = "nearby-chart-scroll-note",
                    "Swipe sideways inside the chart to see the full range."
                  ),
                  div(
                    class = "nearby-curve-legend",
                    span(
                      span(class = "nearby-line-key"),
                      "All recorded venues"
                    ),
                    span(
                      span(class = "nearby-guide-key"),
                      "Current radius"
                    )
                  ),
                  uiOutput(ns("curve")),
                  p(
                    class = "nearby-data-note",
                    "The curve shows venue counts within 1,200 m. The guide marks the selected radius."
                  )
                ),
                p(
                  class = "nearby-analysis-footnote",
                  "Radius changes apply to all three views. Switch to Distance & capacity to compare venues within the selected radius."
                )
              ),
              tabPanel(
                "Distance & capacity",
                value = "patterns",
                panel_card(
                  "Compare distance and recorded capacity",
                  class = "nearby-analysis-card",
                  p(
                    class = "nearby-chart-intro",
                    "Each point is a venue. Click to select; arrow keys move between points and Enter selects."
                  ),
                  p(
                    class = "nearby-chart-scroll-note",
                    "Swipe sideways inside the chart to see the full range."
                  ),
                  category_legend(),
                  uiOutput(ns("scatter"))
                ),
                p(
                  class = "nearby-analysis-footnote",
                  "All views share the selected landmark and venue. Use Show on map to locate a selected point. Records describe venues in the 2024 census."
                )
              )
            )
          )
        )
      )
    )
  )
}
