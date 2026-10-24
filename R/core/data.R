# Read the committed data snapshot directly. No downloads or cleaning at startup.
read_snapshot_csv <- function(path) {
  read.csv(path, stringsAsFactors = FALSE, colClasses = "character",
           fileEncoding = "UTF-8", na.strings = "", check.names = FALSE)
}

require_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) stop(label, " is missing columns: ", paste(missing, collapse = ", "))
}

load_app_data <- function(directory = "data") {
  venues <- read_snapshot_csv(file.path(directory, "venues.csv"))
  landmarks <- read_snapshot_csv(file.path(directory, "landmarks.csv"))
  boundaries <- jsonlite::fromJSON(file.path(directory, "clue_areas.geojson"), simplifyVector = FALSE)
  manifest <- jsonlite::fromJSON(file.path(directory, "manifest.json"), simplifyVector = FALSE)
  require_columns(venues, c("venue_id", "census_year", "property_id", "name", "address", "area",
                           "category_code", "category", "longitude", "latitude", "indoor_seats", "outdoor_seats"), "venues.csv")
  require_columns(landmarks, c("poi_id", "name", "theme", "sub_theme", "longitude", "latitude"), "landmarks.csv")
  for (field in c("census_year", "longitude", "latitude", "indoor_seats", "outdoor_seats")) {
    venues[[field]] <- as.numeric(venues[[field]])
  }
  for (field in c("longitude", "latitude")) landmarks[[field]] <- as.numeric(landmarks[[field]])
  if (anyNA(venues$venue_id) || anyDuplicated(venues$venue_id)) stop("Venue IDs must be non-missing and unique.")
  if (anyNA(landmarks$poi_id) || anyDuplicated(landmarks$poi_id)) stop("Landmark record IDs must be non-missing and unique.")
  if (anyNA(venues[c("longitude", "latitude")]) || anyNA(landmarks[c("longitude", "latitude")])) stop("Coordinates are required.")
  if (!all(is.finite(venues$longitude) & is.finite(venues$latitude)) ||
      !all(is.finite(landmarks$longitude) & is.finite(landmarks$latitude))) stop("Coordinates must be finite.")
  if (!all(venues$census_year == 2024) || !all(venues$category_code %in% c("4511", "4512"))) stop("Unexpected dining snapshot scope.")
  area_names <- vapply(boundaries$features, function(x) x$properties$featurenam, character(1))
  if (!setequal(unique(venues$area), area_names)) stop("Dining area names must match CLUE boundaries.")
  if (nrow(venues) != manifest$audit$venues || nrow(landmarks) != manifest$audit$landmark_records ||
      length(boundaries$features) != manifest$audit$clue_areas) stop("Snapshot counts do not match data/manifest.json.")
  list(venues = venues, landmarks = landmarks, boundaries = boundaries, manifest = manifest,
       areas = sort(unique(venues$area)))
}

# Visitor-oriented selection over the source snapshot, not a live attractions guide.
# Selection policy assisted by OpenAI Codex, 2026-10-25.
# Keep this policy shared: category matches plus named exceptions for broad source
# classes. No records, names or IDs in landmarks.csv are changed by this view.
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
  # Civic/cultural sites, heritage buildings, a market, a zoo, event venues and
  # Flinders Street are named explicitly rather than including all offices,
  # public buildings, sports facilities, shops or railway stations.
  named_sites <- c(
    "State Library Victoria", "NGV International", "Conservatory",
    "Elisabeth Murdoch Hall", "Melbourne Recital Centre", "Sidney Myer Music Bowl",
    "Melbourne Theatre Company", "Shrine of Remembrance", "Melbourne Town Hall",
    "Melbourne Zoo", "Queen Victoria Market", "Parliament House",
    "Old Treasury Building", "Former Royal Mint", "Government House",
    "St Pauls Cathedral", "St Patricks Cathedral", "Scots Church",
    "St Michael's Uniting Church", "Melbourne Cricket Ground (MCG)",
    "Rod Laver Arena", "Melbourne Park", "Hisense Arena", "Etihad Stadium",
    "AAMI Park", "Margaret Court Arena", "Flinders Street Railway Station"
  )
  include <- paste(landmarks$theme, landmarks$sub_theme, sep = "::") %in% visitor_types |
    landmarks$name %in% named_sites
  # The source places this club record in the park/garden category.
  include <- include & !landmarks$name %in% c("Richmond Football Club")
  selected <- landmarks[include, , drop = FALSE]
  selected[order(tolower(selected$name), selected$poi_id, method = "radix"), , drop = FALSE]
}

# Retain the flat name -> poi_id interface used by modules and session defaults.
landmark_choices <- function(data) {
  selected <- tourism_landmarks(data)
  stats::setNames(selected$poi_id, selected$name)
}

get_landmark <- function(data, id) {
  record <- data$landmarks[data$landmarks$poi_id == id, , drop = FALSE]
  if (nrow(record) != 1L) stop("Select exactly one valid landmark record.")
  record
}
