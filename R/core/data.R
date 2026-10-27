# Canonical venue, landmark and boundary data shared by all four pages.
read_snapshot_csv <- function(path) {
  read.csv(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    fileEncoding = "UTF-8",
    na.strings = "",
    check.names = FALSE
  )
}

require_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(label, " is missing columns: ", paste(missing, collapse = ", "))
  }
}

# The bundle carries data frames, GeoJSON boundaries and details indexed by venue_id.
load_app_data <- function(directory = "data") {
  venues <- read_snapshot_csv(file.path(directory, "venues.csv"))
  landmarks <- read_snapshot_csv(file.path(directory, "landmarks.csv"))
  boundaries <- jsonlite::fromJSON(
    file.path(directory, "clue_areas.geojson"),
    simplifyVector = FALSE
  )
  settings <- app_settings()$data
  manifest <- list(
    snapshot_date = settings$snapshot_date,
    audit = settings$expected_counts
  )
  require_columns(
    venues,
    c(
      "venue_id",
      "census_year",
      "property_id",
      "name",
      "address",
      "area",
      "category_code",
      "category",
      "longitude",
      "latitude",
      "indoor_seats",
      "outdoor_seats"
    ),
    "venues.csv"
  )
  require_columns(
    landmarks,
    c("poi_id", "name", "theme", "sub_theme", "longitude", "latitude"),
    "landmarks.csv"
  )
  for (field in c(
    "census_year",
    "longitude",
    "latitude",
    "indoor_seats",
    "outdoor_seats"
  )) {
    venues[[field]] <- as.numeric(venues[[field]])
  }
  for (field in c("longitude", "latitude")) {
    landmarks[[field]] <- as.numeric(landmarks[[field]])
  }
  if (
    anyNA(venues$venue_id) ||
      anyDuplicated(venues$venue_id)
  ) {
    stop("Use one unique ID for each venue.")
  }
  if (
    anyNA(landmarks$poi_id) ||
      anyDuplicated(landmarks$poi_id)
  ) {
    stop("Use one unique ID for each landmark.")
  }
  if (
    anyNA(venues[c("longitude", "latitude")]) ||
      anyNA(landmarks[c("longitude", "latitude")])
  ) {
    stop("Coordinates are required.")
  }
  if (
    !all(
      is.finite(venues$longitude) &
        is.finite(venues$latitude)
    ) ||
      !all(
        is.finite(landmarks$longitude) &
          is.finite(landmarks$latitude)
      )
  ) {
    stop("Coordinates must be finite.")
  }
  if (
    !all(venues$census_year == 2024) ||
      !all(venues$category_code %in% c("4511", "4512"))
  ) {
    stop("Unexpected dining snapshot scope.")
  }
  area_names <- vapply(
    boundaries$features,
    function(x) x$properties$featurenam,
    character(1)
  )
  if (
    !setequal(
      unique(venues$area),
      area_names
    )
  ) {
    stop("Dining area names must match CLUE boundaries.")
  }
  if (
    nrow(venues) != manifest$audit$venues ||
      nrow(landmarks) != manifest$audit$landmark_records ||
      length(boundaries$features) != manifest$audit$clue_areas
  ) {
    stop("Snapshot counts differ from config.json.")
  }
  details_path <- file.path(directory, "venue-details.json")
  details <- if (file.exists(details_path)) {
    jsonlite::fromJSON(details_path, simplifyVector = FALSE)
  } else {
    list(records = list())
  }
  if (
    length(details$records) &&
      (!setequal(
        names(details$records),
        venues$venue_id
      ) ||
        anyDuplicated(names(details$records)))
  ) {
    stop("Offline detail IDs must match the canonical venue snapshot.")
  }
  details_manifest <- list(coverage = settings$details_coverage)
  list(
    venues = venues,
    landmarks = landmarks,
    boundaries = boundaries,
    manifest = manifest,
    areas = sort(unique(venues$area)),
    details = details,
    details_manifest = details_manifest
  )
}

tourism_landmarks <- function(data) {
  landmarks <- data$landmarks
  visitor_types <- c(
    "Place Of Assembly::Art Gallery/Museum",
    "Place Of Assembly::Theatre Live",
    "Place Of Assembly::Cinema",
    "Leisure/Recreation::Informal Outdoor Facility (Park/Garden/Reserve)",
    "Leisure/Recreation::Observation Tower/Wheel",
    "Purpose Built::Aquarium",
    "Transport::Bridge"
  )
  named_sites <- c(
    "State Library Victoria",
    "NGV International",
    "Conservatory",
    "Elisabeth Murdoch Hall",
    "Melbourne Recital Centre",
    "Sidney Myer Music Bowl",
    "Melbourne Theatre Company",
    "Shrine of Remembrance",
    "Melbourne Town Hall",
    "Melbourne Zoo",
    "Queen Victoria Market",
    "Parliament House",
    "Old Treasury Building",
    "Former Royal Mint",
    "Government House",
    "St Pauls Cathedral",
    "St Patricks Cathedral",
    "Scots Church",
    "St Michael's Uniting Church",
    "Melbourne Cricket Ground (MCG)",
    "Rod Laver Arena",
    "Melbourne Park",
    "Hisense Arena",
    "Etihad Stadium",
    "AAMI Park",
    "Margaret Court Arena",
    "Flinders Street Railway Station"
  )
  include <- paste(landmarks$theme, landmarks$sub_theme, sep = "::") %in%
    visitor_types |
    landmarks$name %in% named_sites
  # The source places this club record in the park/garden category.
  include <- include & !landmarks$name %in% c("Richmond Football Club")
  selected <- landmarks[include, , drop = FALSE]
  selected[
    order(
      tolower(selected$name),
      selected$poi_id,
      method = "radix"
    ),
    ,
    drop = FALSE
  ]
}

# Retain the flat name -> poi_id interface used by modules and session defaults.
landmark_choices <- function(data, scope = "tourism") {
  selected <- core_landmarks(data, scope)
  labels <- selected$name
  duplicated_names <- duplicated(labels) |
    duplicated(labels, fromLast = TRUE)
  labels[duplicated_names] <- paste0(
    labels[duplicated_names],
    " · ",
    selected$poi_id[duplicated_names]
  )
  stats::setNames(selected$poi_id, labels)
}

get_landmark <- function(data, id) {
  landmarks <- core_landmarks(data)
  record <- landmarks[landmarks$poi_id == id, , drop = FALSE]
  if (nrow(record) != 1L) {
    stop("Select exactly one valid landmark record.")
  }
  record
}

core_venues <- function(data, area = NULL, category_codes = NULL, ids = NULL) {
  venues <- data$venues
  if (!is.null(area)) {
    if (length(area) != 1L || !area %in% data$areas) {
      stop("Select a CLUE area from the list.")
    }
    venues <- venues[venues$area == area, , drop = FALSE]
  }
  if (!is.null(category_codes)) {
    if (!all(category_codes %in% c("4511", "4512"))) {
      stop("Select a dining category from the list.")
    }
    venues <- venues[venues$category_code %in% category_codes, , drop = FALSE]
  }
  if (!is.null(ids)) {
    rows <- match(ids, venues$venue_id)
    if (anyNA(rows)) {
      stop("Select a venue from the current dataset. in this dataset view")
    }
    venues <- venues[rows, , drop = FALSE]
  }
  venues
}

core_landmarks <- function(data, scope = c("all", "tourism")) {
  scope <- match.arg(scope)
  if (scope == "tourism") {
    return(tourism_landmarks(data))
  }
  data$landmarks[
    order(data$landmarks$name, data$landmarks$poi_id),
    ,
    drop = FALSE
  ]
}

core_boundaries <- function(data, area = NULL) {
  boundaries <- data$boundaries
  if (!is.null(area)) {
    if (length(area) != 1L || !area %in% data$areas) {
      stop("Select a CLUE area from the list.")
    }
    boundaries$features <- Filter(
      function(f) identical(f$properties$featurenam, area),
      boundaries$features
    )
  }
  boundaries
}

core_tableau_overview_url <- function() app_settings()$tableau$url

core_tableau_area_aliases <- function() {
  unlist(app_settings()$tableau$area_aliases)
}

core_check_tableau_counts <- function(data, exported = NULL) {
  if (is.null(exported)) {
    exported <- utils::read.csv(
      paste0(core_tableau_overview_url(), ".csv?:showVizHome=no"),
      check.names = FALSE
    )
  }
  require_columns(
    exported,
    c("Area", "Distinct count of Venue Id"),
    "Tableau overview export"
  )
  aliases <- core_tableau_area_aliases()
  area <- as.character(exported$Area)
  matched <- match(area, unname(aliases))
  area[!is.na(matched)] <- names(aliases)[matched[!is.na(matched)]]
  actual <- suppressWarnings(as.numeric(gsub(
    ",",
    "",
    exported[["Distinct count of Venue Id"]],
    fixed = TRUE
  )))
  expected <- table(core_venues(data)$area)
  ok <- length(area) == length(expected) &&
    !anyDuplicated(area) &&
    setequal(area, names(expected)) &&
    !anyNA(actual) &&
    all(actual == as.numeric(expected[area]))
  list(
    matches = isTRUE(ok),
    areas = length(area),
    total = sum(actual),
    source = core_tableau_overview_url()
  )
}

core_dataset_catalog <- function(data) {
  list(
    snapshot_date = data$manifest$snapshot_date,
    datasets = list(
      venues = list(
        source = "City of Melbourne",
        kind = "snapshot",
        year = 2024,
        rows = nrow(data$venues),
        id = "venue_id",
        file = "data/venues.csv"
      ),
      landmarks = list(
        source = "City of Melbourne",
        kind = "snapshot",
        rows = nrow(data$landmarks),
        id = "poi_id",
        file = "data/landmarks.csv"
      ),
      areas = list(
        source = "City of Melbourne",
        kind = "snapshot",
        rows = length(data$boundaries$features),
        file = "data/clue_areas.geojson"
      ),
      public_details = list(
        source = "OpenStreetMap",
        kind = "offline_enrichment",
        rows = length(data$details$records),
        matched = data$details_manifest$coverage$matched,
        ratings_available = 0L,
        file = "data/venue-details.json"
      ),
      google_details = list(
        source = "Google Places UI Kit",
        kind = "optional_on_demand",
        trigger = "Full details dialog only",
        identity = "user-confirmed Google Place ID",
        persisted_content = FALSE,
        used_in_ranking = FALSE
      ),
      tableau_overview = list(
        source = "City of Melbourne / Tableau Public",
        kind = "published_aggregate",
        url = core_tableau_overview_url(),
        expected_venues = nrow(data$venues),
        expected_areas = length(data$areas),
        area_aliases = as.list(core_tableau_area_aliases())
      )
    ),
    page_views = list(
      area = "selected CLUE area",
      nearby = "tourism landmarks + radius",
      compare = "all landmarks + two catchments",
      route = "ordered landmarks + offline corridor query"
    )
  )
}

core_data_dependencies <- function(data) {
  shiny::tags$head(
    shiny::tags$script(
      id = "core-dataset-catalog",
      type = "application/json",
      shiny::HTML(
        jsonlite::toJSON(
          core_dataset_catalog(data),
          auto_unbox = TRUE
        )
      )
    )
  )
}
