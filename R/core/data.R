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

# A starter selection from the source records; not an exhaustive attraction list.
# The committed landmarks.csv retains all 242 records, including non-tourism places.
landmark_choices <- function(data) {
  names <- c("Federation Square", "State Library Victoria", "Queen Victoria Market",
             "Melbourne Museum", "Immigration Museum", "Australian Centre for Contemporary Art")
  selected <- data$landmarks[match(names, data$landmarks$name), , drop = FALSE]
  selected <- selected[!is.na(selected$poi_id), , drop = FALSE]
  stats::setNames(selected$poi_id, selected$name)
}

get_landmark <- function(data, id) {
  record <- data$landmarks[data$landmarks$poi_id == id, , drop = FALSE]
  if (nrow(record) != 1L) stop("Select exactly one valid landmark record.")
  record
}
