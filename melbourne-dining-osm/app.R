# Run with shiny::runApp("Code/melbourne-dining") from the assignment folder.
# Dependencies are installed separately; startup never installs packages.

# Dependencies and configuration.
if (dir.exists(".Rlibrary")) .libPaths(c(normalizePath(".Rlibrary"), .libPaths()))
needed <- c("shiny")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install the packages listed in README.md: ", paste(missing, collapse = ", "))
if (file.exists(".Renviron")) readRenviron(".Renviron")
library(shiny)

source("R/domain.R", local = TRUE)
source("R/osm_server.R", local = TRUE)

config <- list(
  browser_key = Sys.getenv("GOOGLE_MAPS_BROWSER_KEY"),
  request_limit = suppressWarnings(as.integer(Sys.getenv("PLACES_SESSION_REQUEST_LIMIT", "15")))
)
if (is.na(config$request_limit) || config$request_limit < 1) config$request_limit <- 15L

# Landmark labels retain the existing IDs and duplicate-name handling.
landmarks <- read.csv("data/landmarks.csv", stringsAsFactors = FALSE)
labels <- landmarks$landmark_name
duplicates <- duplicated(labels) | duplicated(labels, fromLast = TRUE)
labels[duplicates] <- paste0(
  labels[duplicates], " · ", landmarks$category[duplicates], " · ",
  substr(landmarks$landmark_id[duplicates], 4, 9)
)
choices <- c(
  "Choose a landmark…" = "",
  setNames(landmarks$landmark_id[order(labels)], labels[order(labels)])
)

# Page layout: controls, map, results and restaurant details.
ui <- fluidPage(
  tags$head(
    tags$title("Melbourne Landmark Dining Explorer"),
    tags$link(rel = "stylesheet", href = "styles.css?v=map-details-layout-20261026"),
    tags$link(
      rel = "stylesheet", href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css",
      integrity = "sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=", crossorigin = "anonymous"
    ),
    tags$script(
      src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js",
      integrity = "sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=", crossorigin = "anonymous"
    ),
    tags$script(src = "osm-explorer.js?v=distance-only-20261025", defer = NA)
  ),
  tags$header(
    class = "site-header",
    div(
      class = "brand",
      span(class = "brand-symbol", "m"),
      div(strong("Melbourne"), span("LANDMARK DINING EXPLORER"))
    ),
    div(class = "header-note", span(class = "status-dot"), "Desktop research prototype")
  ),
  tags$main(
    class = "app-shell",
    div(
      class = "intro",
      div(
        span(class = "eyebrow", "A LITTLE EXPLORING. SOMETHING GOOD TO EAT."),
        h1("Find food near your next stop."),
        p("Pick a landmark, explore nearby restaurants, and keep your day moving.")
      ),
      div(class = "intro-label", "MELBOURNE, AUSTRALIA", span("Distances as the crow flies"))
    ),
    div(
      class = "workspace",

      # Search controls.
      tags$aside(
        class = "control-panel panel",
        span(class = "eyebrow", "PLAN YOUR SEARCH"),
        h2("Around a landmark"),
        selectizeInput(
          "landmark", "1. Your landmark", choices, selected = "",
          options = list(placeholder = "Search a landmark", maxOptions = 300)
        ),
        sliderInput(
          "radius", "Radius (metres)",
          min = 200, max = 1200, value = 600, step = 50, ticks = TRUE, sep = ","
        ),
        p(class = "microcopy", "Distances use recorded coordinates. They are not walking routes."),
        selectInput("cuisine", "3. Primary cuisine", choices = c("All cuisines" = "", cuisine_types)),
        p(class = "microcopy", "Sorted by nearest distance from your selected landmark."),
        actionButton(
          "search", "Search nearby restaurants",
          class = "search-button",
          disabled = NA
        ),
        div(id = "live-status", class = "status-message", role = "status", "Loading map and restaurant search…")
      ),

      # OpenStreetMap and its loading state.
      tags$section(
        class = "map-panel panel",
        div(
          class = "map-heading",
          span(class = "eyebrow", "EXPLORE NEARBY"),
          uiOutput("active_context")
        ),
        div(
          class = "map-stage",
          div(id = "osm-map", `aria-label` = "OpenStreetMap of landmarks and nearby restaurants"),
          div(
            id = "map-message", class = "map-message",
            div(class = "empty-symbol", "+"),
            h3("Your map belongs here"),
            p("Loading OpenStreetMap. Restaurant information uses Google Places UI Kit."),
            tags$a(href = "#connection-setup", "View connection setup")
          )
        ),
        div(
          class = "map-legend",
          span(span(class = "legend-dot landmark"), "Landmark"),
          span(span(class = "legend-dot restaurant"), "Restaurant"),
          span(span(class = "legend-dot selection"), "Selected"),
          span(class = "legend-tail", "Straight-line radius")
        ),
        p(
          class = "map-footnote",
          "242 source locations are available for testing. Final tourism shortlist and importance tiers are pending; landmark markers use equal sizes."
        )
      ),

      # Results share the map's row; selected details occupy the map's column below.
      tags$aside(
        class = "results-panel panel",
        div(
          class = "section-heading",
          h2("Nearby restaurants"),
          span(id = "result-count", "Awaiting search")
        ),
        p(id = "results-order", class = "microcopy", "Up to 10 results · nearest distance"),
        div(class = "results-scroll", div(id = "places-results", p("Choose a landmark and search.")))
      ),
      tags$section(
        class = "detail-panel panel",
        h2("Selected restaurant"),
        p(id = "selected-distance", class = "detail-distance"),
        p(id = "detail-status", role = "status", "Select a restaurant card or numbered map marker."),
        div(id = "places-details")
      )
    ),

    # Connection notes and attribution.
    tags$details(
      id = "connection-setup", class = "setup-panel", tags$summary("Connection setup & prototype notes"),
      textOutput("connection_status"),
      tags$ol(
        tags$li("Set GOOGLE_MAPS_BROWSER_KEY in .Renviron, then restart the app. No server Places key or Google Map ID is used."),
        tags$li("Enable Maps JavaScript API and Places UI Kit API. Restrict browser access to your actual website; set low Cloud quotas.")
      ),
      p("OpenStreetMap loads independently of the Google key. Searches and detail selections can incur Google charges. No restaurant query is sent until you click Search."),
      p("No Google results are saved to files. Current results are cleared after 15 minutes or at Melbourne midnight. Session limits are not an account billing cap."),
      p("Rating, price and hours use Google's widget presentation. Price filtering and rating/price sorting are disabled. Final landmark importance and cuisine coverage need review."),
      p(
        "Landmarks derived from ",
        tags$a(
          href = "https://data.melbourne.vic.gov.au/explore/dataset/landmarks-and-places-of-interest-including-schools-theatres-health-services-spor/information/",
          "City of Melbourne open data", target = "_blank", rel = "noopener noreferrer"
        ),
        " under ",
        tags$a(
          href = "https://creativecommons.org/licenses/by/4.0/", "CC BY 4.0",
          target = "_blank", rel = "noopener noreferrer"
        ),
        ". Changes: normalized fields and generated stable identifiers. No endorsement by City of Melbourne."
      )
    ),
    tags$footer(
      div("GEOM90007 · Tourism interface prototype"),
      div(
        tags$a(href = "terms.html", target = "_blank", "Terms & privacy"), " · ",
        tags$a(
          href = "https://data.melbourne.vic.gov.au/", target = "_blank",
          rel = "noopener noreferrer", "City of Melbourne data"
        )
      )
    )
  )
)

# RStudio Run App must use the same origin allowed by the browser API key.
# Cloud workers are non-interactive and must retain their platform-assigned port.
local_launch <- if (interactive()) list(host = "127.0.0.1", port = 7463L, launch.browser = TRUE) else list()
shinyApp(ui, create_osm_server(config, landmarks), options = local_launch)
