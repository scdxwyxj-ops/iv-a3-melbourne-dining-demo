# GEOM90007 Group 26 starter. Scaffold assisted by OpenAI Codex, 2026-10-11.
# See docs/STARTER_AI_USAGE.md. Four feature modules are placeholders, not a finished submission.
library(shiny)

required_packages <- c("shiny", "jsonlite")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) stop("Install these packages before starting: ", paste(missing_packages, collapse = ", "))

for (file in c("data", "geo", "state", "components", "tableau")) {
  source(file.path("R", "core", paste0(file, ".R")), local = TRUE)
}
for (feature in c("area", "nearby", "compare", "shortlist")) {
  for (part in c("ui", "server")) source(file.path("R", "modules", feature, paste0(part, ".R")), local = TRUE)
}

app_data <- load_app_data("data")

ui <- fluidPage(
  tags$head(
    tags$title("Melbourne Dining Explorer"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$link(rel = "stylesheet", href = "css/common.css"),
    lapply(c("area", "nearby", "compare", "shortlist"), function(x) {
      tags$link(rel = "stylesheet", href = paste0("css/", x, ".css"))
    })
  ),
  tags$header(class = "app-header",
    div(class = "brand", span(class = "brand-mark", "m"),
      div(strong("Melbourne Dining Explorer"), span(class = "brand-subtitle", "SIGHTSEEING + DINING"))),
    span(class = "snapshot-badge", "Dining snapshot · 2024")
  ),
  div(class = "app-shell",
    div(class = "starter-notice", strong("Team starter"),
      "Four feature placeholders with shared styling and ready-to-use data. Maps, Tableau charts and saved lists are still to be implemented."),
    tabsetPanel(id = "main_nav", type = "pills", selected = "nearby",
      tabPanel("1 · Area overview", value = "area", area_ui("area", app_data)),
      tabPanel("2 · Near a landmark", value = "nearby", nearby_ui("nearby", app_data)),
      tabPanel("3 · Compare places", value = "compare", compare_ui("compare", app_data)),
      tabPanel("4 · Details & shortlist", value = "shortlist", shortlist_ui("shortlist", app_data))
    ),
    tags$footer(class = "app-footer",
      span("Source: City of Melbourne · ", tags$a(href = "https://creativecommons.org/licenses/by/4.0/", "CC BY 4.0", target = "_blank", rel = "noopener noreferrer")),
      span("Historical records · Distances are straight-line estimates"))
  )
)

server <- function(input, output, session) {
  # Every visitor gets a separate state object. Never create this globally.
  state <- create_shared_state(app_data)
  area_server("area", app_data, state)
  nearby_server("nearby", app_data, state)
  compare_server("compare", app_data, state)
  shortlist_server("shortlist", app_data, state)
}

shinyApp(ui, server)
