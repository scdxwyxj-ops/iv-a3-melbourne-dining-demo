library(shiny)

required_packages <- c("shiny", "jsonlite", "shinyjs")
missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )
]
if (length(missing_packages)) {
  stop(
    "Install these packages before starting: ",
    paste(missing_packages, collapse = ", ")
  )
}

source("R/bootstrap.R", local = TRUE)
load_app_code(environment())

app_data <- load_app_data("data")

ui <- fluidPage(
  core_data_dependencies(app_data),
  core_map_dependencies(),
  core_google_dependencies(),
  setUpTableauInShiny(),
  tags$head(
    tags$title(app_settings()$app$title),
    tags$link(rel = "stylesheet", href = "css/details.css?v=4.6"),
    tags$meta(
      name = "viewport",
      content = "width=device-width, initial-scale=1"
    ),
    tags$link(rel = "stylesheet", href = "css/common.css"),
    lapply(
      c("area", "nearby", "compare", "route"),
      function(x) {
        tags$link(rel = "stylesheet", href = paste0("css/", x, ".css?v=4.6"))
      }
    )
  ),
  tags$header(
    class = "app-header",
    div(
      class = "brand",
      span(class = "brand-mark", "m"),
      div(
        strong("Melbourne Dining Explorer"),
        span(class = "brand-subtitle", "SIGHTSEEING + DINING")
      )
    ),
    span(class = "snapshot-badge", textOutput("source_badge", inline = TRUE))
  ),
  div(
    class = "app-shell",
    tabsetPanel(
      id = "main_nav",
      type = "pills",
      selected = "nearby",
      tabPanel("1 · Area overview", value = "area", area_ui("area", app_data)),
      tabPanel(
        "2 · Near a landmark",
        value = "nearby",
        nearby_ui("nearby", app_data)
      ),
      tabPanel(
        "3 · Compare places",
        value = "compare",
        compare_ui("compare", app_data)
      ),
      tabPanel(
        "4 · Dining along your route",
        value = "route",
        route_ui("route", app_data)
      )
    ),
    tags$footer(
      class = "app-footer",
      span(
        "Source: City of Melbourne · ",
        tags$a(
          href = "https://creativecommons.org/licenses/by/4.0/",
          "CC BY 4.0",
          target = "_blank",
          rel = "noopener noreferrer"
        )
      ),
      span(
        "Straight-line planning · ",
        tags$a(
          href = "https://www.openstreetmap.org/copyright",
          "OSM contributors · ODbL",
          target = "_blank",
          rel = "noopener noreferrer"
        ),
        " · ",
        tags$a(href = "privacy.html", "Privacy", target = "_blank"),
        " · ",
        tags$a(href = "terms.html", "Terms", target = "_blank")
      )
    )
  )
)

server <- function(input, output, session) {
  state <- create_shared_state(app_data)
  output$source_badge <- renderText("2024 census + public details snapshot")
  tableau_area_server(input, session, state, app_data$areas)
  area_server("area", app_data, state)
  nearby_server("nearby", app_data, state)
  compare_server("compare", app_data, state)
  route_server("route", app_data, state)
}

shinyApp(ui, server)
