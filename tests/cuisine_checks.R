# Cuisine UI was retired at the user's request. Retain only the research-data integrity check.
records <- jsonlite::fromJSON("data/venue-cuisines.json", simplifyVector = FALSE)$matches
ids <- vapply(records, `[[`, character(1), "venue_id")
stopifnot(!anyDuplicated(ids), all(nzchar(ids)))
cat("PASS: archived cuisine research IDs are unique; not used by Compare.\n")
