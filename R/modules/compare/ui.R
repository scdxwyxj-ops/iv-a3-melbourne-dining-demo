compare_ui <- function(id, data) {
  ns <- NS(id)
  landmarks <- core_landmarks(data, "all")
  choices <- landmark_choices(data, "all")
  landmark_card <- function(letter, field, selected, tone) {
    div(
      class = paste("compare-place", tone),
      span(class = "compare-letter", letter),
      div(
        class = "compare-place-input",
        selectizeInput(
          ns(field),
          paste("Landmark", letter),
          choices,
          selected = landmarks$poi_id[match(selected, landmarks$name)],
          options = list(placeholder = "Search all landmarks")
        ),
        span(class = "compare-place-caption", "MELBOURNE · VICTORIA")
      )
    )
  }
  div(
    class = "compare-page",
    div(
      class = "compare-workspace",
      tags$aside(
        class = "compare-sidebar",
        `aria-label` = "Comparison settings and results",
        div(
          class = "compare-heading",
          p(class = "compare-eyebrow", "MELBOURNE / EXPLORE & COMPARE"),
          h1("Compare your next stops"),
          p("Find the better place for a food break.")
        ),
        landmark_card("A", "landmark_a", "Federation Square", "place-a"),
        landmark_card("B", "landmark_b", "State Library Victoria", "place-b"),
        div(
          class = "compare-radius",
          sliderInput(
            ns("radius"),
            "Search radius · same for both places",
            min = app_settings()$compare$radius_min_m,
            max = app_settings()$compare$radius_max_m,
            value = app_settings()$compare$radius_default_m,
            step = app_settings()$compare$radius_step_m,
            post = " m",
            sep = ","
          )
        ),
        selectInput(
          ns("category"),
          "Show venues",
          c(
            `All dining` = "all",
            `Cafes & restaurants` = "4511",
            Takeaway = "4512"
          )
        ),
        uiOutput(ns("notice")),
        uiOutput(ns("counts")),
        uiOutput(ns("insight")),
        div(
          class = "compare-mix",
          h2("Compare dining mix"),
          uiOutput(ns("chart"))
        ),
        actionButton(
          ns("explore"),
          "Explore shared venues",
          class = "btn-primary compare-explore",
          icon = icon("list")
        ),
        p(
          class = "compare-footnote",
          paste(
            format(
              nrow(core_venues(data)),
              big.mark = ","
            ),
            "venues ·",
            nrow(core_landmarks(data)),
            "landmark records"
          ),
          tags$br(),
          "City of Melbourne council area.",
          tags$br(),
          "Landmarks include non-tourism facilities. 2024 dining census · Straight-line distances.",
          tags$br(),
          "Shared venues are counted in both A and B.",
          tags$br(),
          "Point colours show A only, B only or both catchments; dark A/B markers identify landmarks."
        )
      ),
      tags$section(
        class = "compare-map-panel",
        `aria-label` = "Map of both dining catchments",
        core_map_ui(
          ns("map"),
          height = "100%",
          label = "Map of both dining catchments"
        ),
        div(
          class = "compare-map-toolbar",
          span(
            class = "compare-map-city",
            icon("location-dot"),
            " Melbourne"
          ),
          uiOutput(
            ns("map_scope"),
            inline = TRUE
          ),
          actionButton(
            ns("recenter"),
            "Fit both",
            icon = icon("expand")
          )
        ),
        uiOutput(
          ns("venue_card"),
          class = "compare-card-slot"
        ),
        div(
          class = "compare-map-legend",
          span(class = "key-a", "● A only"),
          span(class = "key-b", "● B only"),
          span(class = "key-shared", "● Both")
        ),
        div(
          class = "compare-map-note",
          "City of Melbourne · 2024 dining snapshot"
        )
      )
    )
  )
}
