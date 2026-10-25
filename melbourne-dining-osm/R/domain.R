# Pure transformations. No network calls, no disk writes, no fabricated attributes.
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
missing_label <- "No data available"
scalar_text <- function(x, fallback = missing_label) {
  if (is.null(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(as.character(x)))) fallback else as.character(x)
}
number_or_na <- function(x) {
  value <- suppressWarnings(as.numeric(x %||% NA_real_))
  if (length(value) != 1L || !is.finite(value)) NA_real_ else value
}
melbourne_date <- function(time = Sys.time()) as.Date(format(time, tz = "Australia/Melbourne", format = "%Y-%m-%d"))
haversine_m <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  a <- sin((lat2 - lat1) * rad / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin((lon2 - lon1) * rad / 2)^2
  6371008.8 * 2 * atan2(sqrt(pmin(1, pmax(0, a))), sqrt(1 - pmin(1, pmax(0, a))))
}
distance_label <- function(m) {
  if (!is.finite(m)) return(missing_label)
  if (m < 1000) paste0(round(m), " m") else sprintf("%.2f km", m / 1000)
}
cuisine_types <- c(
  "Chinese" = "chinese_restaurant", "French" = "french_restaurant",
  "Greek" = "greek_restaurant", "Indian" = "indian_restaurant",
  "Italian" = "italian_restaurant", "Japanese" = "japanese_restaurant",
  "Korean" = "korean_restaurant", "Lebanese" = "lebanese_restaurant",
  "Mexican" = "mexican_restaurant", "Spanish" = "spanish_restaurant",
  "Thai" = "thai_restaurant", "Turkish" = "turkish_restaurant",
  "Vietnamese" = "vietnamese_restaurant"
)
# Only unambiguous PRIMARY types are mapped. Secondary tags are not primary cuisine.
cuisine_label <- function(primary_type) {
  i <- match(primary_type, unname(cuisine_types))
  if (is.na(i)) missing_label else names(cuisine_types)[i]
}
price_levels <- c("Inexpensive" = "PRICE_LEVEL_INEXPENSIVE", "Moderate" = "PRICE_LEVEL_MODERATE",
                  "Expensive" = "PRICE_LEVEL_EXPENSIVE", "Very expensive" = "PRICE_LEVEL_VERY_EXPENSIVE")
price_rank <- function(level) {
  if (identical(level, "PRICE_LEVEL_FREE")) return(0L)
  match(level, unname(price_levels))
}
money_value <- function(money) {
  if (is.null(money)) return(NA_real_)
  units <- number_or_na(money$units %||% 0)
  nanos <- number_or_na(money$nanos %||% 0)
  units + nanos / 1e9
}
price_label <- function(place) {
  range <- place$priceRange
  low <- money_value(range$startPrice)
  high <- money_value(range$endPrice)
  currency <- range$startPrice$currencyCode %||% range$endPrice$currencyCode %||% ""
  if (currency == "AUD" && is.finite(low) && (is.na(high) || high >= low)) {
    if (is.na(high)) return(sprintf("A$%g+", low))
    return(sprintf("A$%g–<%g", low, high))
  }
  level <- scalar_text(place$priceLevel, "")
  if (level == "PRICE_LEVEL_FREE") return("Free")
  i <- match(level, unname(price_levels))
  if (is.na(i)) missing_label else names(price_levels)[i]
}
point_minutes <- function(point, today) {
  hour <- number_or_na(point$hour %||% 0)
  minute <- number_or_na(point$minute %||% 0)
  if (!is.null(point$date)) {
    date <- point$date
    parsed <- tryCatch(as.Date(sprintf("%04d-%02d-%02d", date$year, date$month, date$day)), error = function(e) as.Date(NA))
    return(as.numeric(parsed - today) * 1440 + hour * 60 + minute)
  }
  NA_real_
}
hours_today <- function(hours, today = melbourne_date()) {
  if (is.null(hours)) return(missing_label)
  periods <- hours$periods %||% list()
  # Google's documented always-open representation.
  if (length(periods) == 1 && is.null(periods[[1]]$close)) {
    op <- periods[[1]]$open
    if (identical(as.integer(op$day), 0L) && (op$hour %||% 0) == 0 && (op$minute %||% 0) == 0 && !isTRUE(op$truncated)) return("Open 24 hours")
  }
  intervals <- list()
  all_dated <- length(periods) > 0
  for (period in periods) {
    start <- point_minutes(period$open, today)
    end <- point_minutes(period$close, today)
    if (!is.finite(start) || !is.finite(end)) { all_dated <- FALSE; next }
    if (end > 0 && start < 1440 && end > start) intervals[[length(intervals) + 1L]] <- c(max(0, start), min(1440, end))
  }
  clock <- function(x) if (x == 1440) "24:00" else sprintf("%02d:%02d", as.integer(x %/% 60), as.integer(x %% 60))
  if (all_dated) {
    if (!length(intervals)) return("Closed today")
    return(paste(vapply(intervals, function(x) paste0(clock(x[1]), "–", clock(x[2])), character(1)), collapse = ", "))
  }
  # Locale-independent selection of an English weekday description, not array index.
  days <- c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
  day <- days[as.POSIXlt(today)$wday + 1L]
  descriptions <- unlist(hours$weekdayDescriptions %||% list(), use.names = FALSE)
  line <- descriptions[grepl(paste0("^", day, ":"), descriptions)]
  if (length(line)) sub(paste0("^", day, ":\\s*"), "", line[1]) else missing_label
}
empty_restaurants <- function() data.frame(
  restaurant_id = character(), restaurant_name = character(), latitude = numeric(), longitude = numeric(),
  primary_type = character(), primary_cuisine = character(), price_level = character(), price_rank = numeric(),
  price_label = character(), rating = numeric(), opening_hours_today = character(), address = character(),
  distance_m = numeric(), google_maps_uri = character(), stringsAsFactors = FALSE
)
normalize_places <- function(places, landmark, today = melbourne_date()) {
  if (!length(places)) return(empty_restaurants())
  rows <- lapply(places, function(p) {
    lat <- number_or_na(p$location$latitude); lon <- number_or_na(p$location$longitude)
    id <- scalar_text(p$id, "")
    if (!nzchar(id) || !is.finite(lat) || !is.finite(lon) || abs(lat) > 90 || abs(lon) > 180) return(NULL)
    primary <- scalar_text(p$primaryType, "")
    rating <- number_or_na(p$rating)
    if (!is.na(rating) && (rating < 1 || rating > 5)) rating <- NA_real_
    data.frame(restaurant_id = id, restaurant_name = scalar_text(p$displayName$text), latitude = lat, longitude = lon,
      primary_type = primary, primary_cuisine = cuisine_label(primary), price_level = scalar_text(p$priceLevel, ""),
      price_rank = price_rank(scalar_text(p$priceLevel, "")), price_label = price_label(p), rating = rating,
      opening_hours_today = hours_today(p$currentOpeningHours, today), address = scalar_text(p$formattedAddress),
      distance_m = haversine_m(landmark$latitude, landmark$longitude, lat, lon),
      google_maps_uri = scalar_text(p$googleMapsUri, ""), stringsAsFactors = FALSE)
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(empty_restaurants())
  data <- do.call(rbind, rows)
  data[!duplicated(data$restaurant_id), , drop = FALSE]
}
filter_sort <- function(data, radius, cuisine = "", price = "", sort = "rating") {
  out <- data[is.finite(data$distance_m) & data$distance_m <= radius, , drop = FALSE]
  if (nzchar(cuisine)) out <- out[out$primary_type == cuisine, , drop = FALSE]
  if (nzchar(price)) {
    out <- if (price == "unknown") out[is.na(out$price_rank), , drop = FALSE] else out[out$price_level == price, , drop = FALSE]
  }
  field <- switch(sort, rating = -out$rating, distance = out$distance_m,
                  price_low = out$price_rank, price_high = -out$price_rank, out$distance_m)
  out[order(is.na(field), field, out$distance_m, tolower(out$restaurant_name), out$restaurant_id, na.last = TRUE), , drop = FALSE]
}
safe_web_url <- function(url) grepl("^https://[^[:space:]]+$", url)
