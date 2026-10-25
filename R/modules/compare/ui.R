compare_ui <- function(id, data) {
  ns <- NS(id)
  landmarks <- data$landmarks[order(data$landmarks$name, data$landmarks$poi_id), , drop = FALSE]
  labels <- landmarks$name
  duplicated_names <- duplicated(labels) | duplicated(labels, fromLast = TRUE)
  labels[duplicated_names] <- paste0(labels[duplicated_names], " · ", landmarks$poi_id[duplicated_names])
  choices <- stats::setNames(landmarks$poi_id, labels)
  landmark_card <- function(letter, field, selected, tone) {
    div(class = paste("compare-place", tone),
      span(class = "compare-letter", letter),
      div(class = "compare-place-input", selectizeInput(ns(field), paste("Landmark", letter), choices,
        selected = landmarks$poi_id[match(selected, landmarks$name)], options = list(placeholder = "Search all landmarks")),
        span(class = "compare-place-caption", "MELBOURNE · VICTORIA")),
      uiOutput(ns(paste0("photo_", tolower(letter))), class = "compare-place-photo"))
  }
  div(class = "compare-page",
    div(class = "compare-workspace",
      tags$aside(class = "compare-sidebar", `aria-label` = "Comparison settings and results",
        div(class = "compare-heading", p(class = "compare-eyebrow", "MELBOURNE / EXPLORE & COMPARE"),
          h1("Compare your next stops"), p("Find the better place for a food break.")),
        landmark_card("A", "landmark_a", "Federation Square", "place-a"),
        landmark_card("B", "landmark_b", "State Library Victoria", "place-b"),
        div(class = "compare-radius", sliderInput(ns("radius"), "Search radius · same for both places",
          min = 200, max = 1200, value = 600, step = 1, post = " m", sep = ",")),
        selectInput(ns("category"), "Show venues", c("All dining" = "all", "Cafes & restaurants" = "4511", "Takeaway" = "4512")),
        uiOutput(ns("notice")), uiOutput(ns("counts")), uiOutput(ns("insight")),
        div(class = "compare-mix", h2("Compare dining mix"), uiOutput(ns("chart"))),
        actionButton(ns("explore"), "Explore shared venues", class = "btn-primary compare-explore", icon = icon("list")),
        p(class = "compare-footnote", paste(format(nrow(data$venues), big.mark = ","), "venues ·", nrow(data$landmarks), "landmark records"),
          tags$br(), "City of Melbourne council area, not Greater Melbourne.", tags$br(),
          "Landmarks include non-tourism facilities. 2024 dining census · Straight-line distances.",
          tags$br(), "Shared venues are counted in both A and B.")),
      tags$section(class = "compare-map-panel", `aria-label` = "Map of both dining catchments",
        leaflet::leafletOutput(ns("map"), height = "100%"),
        div(class = "compare-map-toolbar", span(class = "compare-map-city", icon("location-dot"), " Melbourne"),
          uiOutput(ns("map_scope"), inline = TRUE), actionButton(ns("recenter"), "Fit both", icon = icon("expand"))),
        uiOutput(ns("venue_card"), class = "compare-card-slot"),
        div(class = "compare-map-legend", span(class = "key-a", "● A only"), span(class = "key-b", "● B only"), span(class = "key-shared", "● Both")),
        div(class = "compare-map-note", "City of Melbourne · 2024 dining snapshot"))))
}
