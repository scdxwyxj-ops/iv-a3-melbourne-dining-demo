# Shared geography contract. Route distance and travel time are outside this demo.
haversine_m <- function(longitude, latitude, origin_longitude, origin_latitude) {
  if (length(origin_longitude) != 1L || length(origin_latitude) != 1L ||
      !is.finite(origin_longitude) || !is.finite(origin_latitude)) stop("A finite origin is required.")
  radians <- pi / 180
  lat1 <- origin_latitude * radians
  lat2 <- latitude * radians
  delta_lat <- lat2 - lat1
  delta_lon <- (longitude - origin_longitude) * radians
  a <- sin(delta_lat / 2)^2 + cos(lat1) * cos(lat2) * sin(delta_lon / 2)^2
  6371008.8 * 2 * asin(sqrt(pmin(1, pmax(0, a))))
}

venues_near <- function(data, landmark_id, radius_m = 600) {
  if (length(radius_m) != 1L || !is.finite(radius_m) || radius_m < 0) stop("Radius must be a non-negative number of metres.")
  origin <- get_landmark(data, landmark_id)
  venues <- data$venues
  venues$distance_m <- haversine_m(venues$longitude, venues$latitude, origin$longitude, origin$latitude)
  venues <- venues[venues$distance_m <= radius_m, , drop = FALSE]
  venues[order(venues$distance_m, venues$name, venues$venue_id), , drop = FALSE]
}
