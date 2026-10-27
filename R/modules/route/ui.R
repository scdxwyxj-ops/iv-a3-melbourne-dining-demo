route_ui <- function(id, data) {
  ns <- NS(id)
  div(
    class = "route-page",
    `data-namespace` = ns(""),
    div(
      class = "feature-heading",
      div(
        h1("A meal stop along your day"),
        p(
          "Keep your sightseeing order. Explore the route, venue mix and recommendations in separate views."
        )
      )
    ),
    div(
      class = "route-layout",
      panel_card(
        "Your itinerary",
        class = "route-controls",
        div(
          class = "route-control-tabs",
          tabsetPanel(
            id = ns("settings"),
            type = "tabs",
            selected = "stops",
            tabPanel(
              "Stops",
              value = "stops",
              p(
                class = "route-help",
                "Stops stay in your chosen order. Move them up or down to change the day."
              ),
              div(class = "route-stop-list", uiOutput(ns("stops"))),
              selectizeInput(
                ns("new_stop"),
                "Add a sightseeing stop",
                c(`Choose a landmark…` = "", landmark_choices(data)),
                selected = "",
                options = list(placeholder = "Search tourist landmarks")
              ),
              actionButton(
                ns("add_stop"),
                "Add stop",
                class = "btn-default"
              ),
              p(
                class = "route-help",
                textOutput(
                  ns("edit_note"),
                  inline = TRUE
                )
              )
            ),
            tabPanel(
              "Preferences",
              value = "preferences",
              sliderInput(
                ns("radius"),
                "Maximum offset from the route",
                min = app_settings()$route$radius_min_m,
                max = app_settings()$route$radius_max_m,
                value = app_settings()$route$radius_default_m,
                step = app_settings()$route$radius_step_m,
                post = " m",
                sep = ","
              ),
              sliderInput(
                ns("target"),
                "Preferred meal position in the trip",
                min = 0,
                max = 100,
                value = 100 * app_settings()$route$target_default,
                step = 5,
                post = "%"
              ),
              selectInput(
                ns("mode"),
                "Suggestion priority",
                c(
                  Balanced = "balanced",
                  `Smallest extra distance` = "least_detour",
                  `Near the meal position` = "meal_position"
                )
              ),
              selectInput(
                ns("category"),
                "Venue format",
                c(
                  `All dining` = "all",
                  `Cafés & restaurants` = "4511",
                  Takeaway = "4512"
                )
              ),
              tags$details(
                class = "route-formula",
                tags$summary("How the plan-fit score works"),
                uiOutput(ns("formula")),
                p(
                  "The score combines extra distance and the preferred meal position."
                )
              )
            )
          )
        ),
        p(
          class = "route-help",
          "Straight lines connect your sightseeing stops."
        )
      ),
      div(
        class = "route-main",
        uiOutput(ns("summary")),
        uiOutput(ns("selection_context")),
        div(
          class = "route-view-tabs",
          tabsetPanel(
            id = ns("view"),
            type = "tabs",
            selected = "map",
            tabPanel(
              "Route map",
              value = "map",
              panel_card(
                "Your route and dining corridor",
                class = "route-map-card",
                div(
                  class = "route-map-heading",
                  uiOutput(ns("route_note")),
                  actionButton(
                    ns("fit"),
                    "Fit itinerary",
                    class = "btn-default"
                  )
                ),
                core_map_ui(
                  ns("map"),
                  height = "430px",
                  label = "Ordered sightseeing route and nearby dining venues"
                ),
                div(
                  class = "route-map-legend",
                  category_legend(),
                  span(class = "route-line-key", "Sightseeing order"),
                  span(class = "route-detour-key", "Selected meal detour")
                ),
                p(
                  class = "route-help",
                  "The pale corridor is the allowed offset around each line. Dark numbered markers are sightseeing stops; numbered dining circles contain several venues at one location."
                )
              )
            ),
            tabPanel(
              "Venue mix",
              value = "mix",
              panel_card(
                "Dining choices by format",
                class = "route-format-card",
                p(
                  class = "route-help",
                  "Counts and shares cover every candidate in the current corridor and venue-format filter."
                ),
                uiOutput(ns("mix"))
              )
            ),
            tabPanel(
              "Along the route",
              value = "distribution",
              panel_card(
                "Where the dining choices sit",
                class = "route-pattern-card",
                p(
                  class = "route-help",
                  "Each point is one candidate venue, placed at its suggested insertion leg. Choose a point, then open Why this choice to inspect its recommendation."
                ),
                uiOutput(ns("distribution"))
              )
            ),
            tabPanel(
              "Recommendations",
              value = "recommendations",
              div(
                class = "route-recommendations-layout",
                panel_card(
                  "Suggested meal stops",
                  class = "route-suggestions",
                  p(
                    class = "route-help",
                    "Plan fit combines extra distance and meal position."
                  ),
                  div(class = "route-ranked-scroll", uiOutput(ns("ranked"))),
                  downloadButton(
                    ns("export"),
                    "Export suggestions",
                    class = "btn-default"
                  )
                ),
                panel_card(
                  "Why this venue fits",
                  class = "route-explanation",
                  uiOutput(ns("selection"))
                )
              )
            )
          )
        )
      )
    ),
    tags$script(src = "route/route.js?v=4.2")
  )
}
