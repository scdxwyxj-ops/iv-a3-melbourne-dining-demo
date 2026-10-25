# Reproducible conservative join. Run from repository root with the source CSV path.
args <- commandArgs(trailingOnly = TRUE)
source("R/core/geo.R")
v <- read.csv("data/venues.csv", stringsAsFactors = FALSE, fileEncoding = "UTF-8")
o <- read.csv(args[1], stringsAsFactors = FALSE, fileEncoding = "UTF-8", colClasses = "character")
norm <- function(x) gsub("[^a-z0-9]", "", tolower(iconv(x, to = "ASCII//TRANSLIT")))
vn <- norm(v$name); on <- norm(o$name)
rows <- list()
for (i in seq_len(nrow(v))) {
  possible <- which(on == vn[i] & !is.na(on) & nzchar(on))
  if (!length(possible)) next
  distance <- haversine_m(as.numeric(o$lon[possible]), as.numeric(o$lat[possible]), v$longitude[i], v$latitude[i])
  candidates <- possible[is.finite(distance) & distance <= 100]
  if (length(candidates) != 1) next
  j <- candidates[1]
  reverse <- which(vn == on[j] & haversine_m(v$longitude, v$latitude, as.numeric(o$lon[j]), as.numeric(o$lat[j])) <= 100)
  if (length(reverse) != 1) next
  tags <- trimws(tolower(strsplit(ifelse(is.na(o$cuisine[j]), "", o$cuisine[j]), ";", fixed = TRUE)[[1]]))
  labels <- intersect(c("japanese", "korean", "thai", "chinese", "italian"), tags)
  if (o$amenity[j] == "cafe") labels <- c(labels, "cafe")
  # Retain unmapped tags as Other; never infer nationality from a name or dish.
  if (any(nzchar(tags) & !tags %in% c("japanese", "korean", "thai", "chinese", "italian", "coffee_shop", "coffee"))) labels <- c(labels, "other")
  if (!length(labels)) labels <- "unknown"
  rows[[length(rows)+1]] <- list(venue_id = v$venue_id[i], venue_name = v$name[i], venue_address = v$address[i],
    osm_name = o$name[j], osm_address = o$address_full[j], osm_id = o$osm_id[j], osm_type = o$type[j],
    distance_m = round(distance[match(j, possible)], 1), cuisine_raw = o$cuisine[j], amenity = o$amenity[j],
    labels = labels, source_url = paste0("https://www.openstreetmap.org/", o$type[j], "/", o$osm_id[j]),
    match_method = "unique normalised exact name within 100 m; reciprocal uniqueness")
}
payload <- list(source = "https://huggingface.co/datasets/CITTYJAMES/melbourne-cafes-restaurants-osm",
  source_snapshot_date = "2025-10-22", census_year = 2024, retrieved_date = as.character(Sys.Date()),
  licence = "ODbL-1.0", attribution = "OpenStreetMap contributors; snapshot published by CITTYJAMES (Heidi Gaddi)",
  total_venues = nrow(v), source_records = nrow(o), matches = rows)
jsonlite::write_json(payload, args[2], pretty = TRUE, auto_unbox = TRUE, na = "null")
cat("Source rows:", nrow(o), "Matched:", length(rows), "Classified:", sum(vapply(rows,function(r) !identical(r$labels,"unknown"),logical(1))), "\n")
print(table(unlist(lapply(rows, `[[`, "labels"))))
