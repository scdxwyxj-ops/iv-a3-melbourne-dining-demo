# Ordered-route projection, candidate selection and itinerary-fit scoring.
# Ordered straight-line route geometry and deterministic itinerary-fit ranking.  Coordinates
# enter/leave as longitude/latitude degrees; all calculations use metres.
ROUTE_MAX_STOPS <- as.integer(app_settings()$route$max_stops)
ROUTE_ZERO_LENGTH_M <- 1e-06
ROUTE_RADIUS_TOLERANCE_M <- 1e-08
ROUTE_DETOUR_TIE_DIGITS <- 6L

route_input_error <- function(message) {
  stop(
    structure(
      list(message = message, call = NULL),
      class = c("route_input_error", "error", "condition")
    )
  )
}

# Returns ordered nodes, projected xy coordinates, leg lengths and cumulative metres.  Repeated
# stops are retained; zero-length legs are excluded from candidate calculations.
core_route_model <- function(data, stop_ids) {
  if (
    !is.character(stop_ids) ||
      length(stop_ids) < 2L ||
      length(stop_ids) > ROUTE_MAX_STOPS
  ) {
    route_input_error("Choose two to eight ordered stops.")
  }
  nodes <- do.call(rbind, lapply(stop_ids, function(id) get_landmark(data, id)))
  rownames(nodes) <- NULL
  origin <- c(
    longitude = mean(nodes$longitude),
    latitude = mean(nodes$latitude)
  )
  xy <- core_route_project(nodes$longitude, nodes$latitude, origin)
  leg_lengths <- sqrt(
    rowSums(
      (xy[-1, , drop = FALSE] - xy[-nrow(xy), , drop = FALSE])^2
    )
  )
  if (sum(leg_lengths) < ROUTE_ZERO_LENGTH_M) {
    route_input_error("The route needs at least two different locations.")
  }
  list(
    ids = stop_ids,
    nodes = nodes,
    origin = origin,
    xy = xy,
    lengths = leg_lengths,
    cumulative = c(0, cumsum(leg_lengths)),
    total_m = sum(leg_lengths),
    legs = which(leg_lengths > ROUTE_ZERO_LENGTH_M)
  )
}

# City-scale equirectangular approximation centred on the itinerary's mean location.
core_route_project <- function(longitude, latitude, origin) {
  radians <- pi / 180
  cbind(
    x = CORE_EARTH_RADIUS_M *
      radians *
      (longitude - origin[["longitude"]]) *
      cos(origin[["latitude"]] * radians),
    y = CORE_EARTH_RADIUS_M * radians * (latitude - origin[["latitude"]])
  )
}

core_route_unproject <- function(x, y, origin) {
  radians <- pi / 180
  cbind(
    longitude = origin[["longitude"]] +
      x / (CORE_EARTH_RADIUS_M * radians * cos(origin[["latitude"]] * radians)),
    latitude = origin[["latitude"]] + y / (CORE_EARTH_RADIUS_M * radians)
  )
}

core_route_weights <- function(
  mode = c("balanced", "least_detour", "meal_position")
) {
  mode <- match.arg(mode)
  unlist(app_settings()$route$weights[[mode]])
}

# Every empty result has the same columns as a populated candidate table.
core_empty_route_results <- function(data) {
  result <- core_venues(data)[FALSE, , drop = FALSE]
  fields <- c(
    "route_distance_m",
    "offset_m",
    "detour_m",
    "progress",
    "leg",
    "projection_lon",
    "projection_lat",
    "detour_component",
    "position_component",
    "fit_score",
    "recommend_rank"
  )
  for (field in fields) {
    result[[field]] <- numeric(0)
  }
  result
}

core_route_leg_metrics <- function(points, model) {
  venue_count <- nrow(points)
  leg_count <- length(model$legs)
  offsets <- detours <- positions <- projection_x <- projection_y <- matrix(
    0,
    venue_count,
    leg_count
  )

  for (column in seq_along(model$legs)) {
    leg_index <- model$legs[column]
    start <- model$xy[leg_index, ]
    end <- model$xy[leg_index + 1L, ]
    direction <- end - start
    projection_fraction <- ((points[, 1] - start[1]) *
      direction[1] +
      (points[, 2] - start[2]) *
        direction[2]) /
      sum(direction^2)
    projection_fraction <- pmax(0, pmin(1, projection_fraction))

    projection_x[, column] <- start[1] + projection_fraction * direction[1]
    projection_y[, column] <- start[2] + projection_fraction * direction[2]
    offsets[, column] <- sqrt(
      (points[, 1] - projection_x[, column])^2 +
        (points[, 2] - projection_y[, column])^2
    )
    detours[, column] <- pmax(
      0,
      sqrt(rowSums(sweep(points, 2, start)^2)) +
        sqrt(rowSums(sweep(points, 2, end)^2)) -
        model$lengths[leg_index]
    )
    positions[, column] <- (model$cumulative[leg_index] +
      projection_fraction * model$lengths[leg_index]) /
      model$total_m
  }
  list(
    offsets = offsets,
    detours = detours,
    positions = positions,
    projection_x = projection_x,
    projection_y = projection_y
  )
}

core_route_choose_legs <- function(metrics, model, rows, radius_m, target) {
  vapply(
    rows,
    function(row) {
      eligible <- which(
        metrics$offsets[row, ] <= radius_m + ROUTE_RADIUS_TOLERANCE_M
      )
      order_index <- order(
        round(metrics$detours[row, eligible], ROUTE_DETOUR_TIE_DIGITS),
        abs(metrics$positions[row, eligible] - target),
        model$legs[eligible]
      )
      eligible[order_index[1L]]
    },
    integer(1)
  )
}

# Progress and target are fractions in [0, 1]; contributions sum on a [0, 100] scale.
core_route_score <- function(candidates, radius_m, target, weights) {
  detour_fit <- pmax(0, pmin(1, 1 - candidates$detour_m / (2 * radius_m)))
  position_fit <- pmax(
    0,
    1 - abs(candidates$progress - target) / max(target, 1 - target)
  )
  candidates$detour_component <- 100 * weights[["detour"]] * detour_fit
  candidates$position_component <- 100 * weights[["position"]] * position_fit
  candidates$fit_score <- candidates$detour_component +
    candidates$position_component
  candidates
}

core_route_rank <- function(candidates) {
  ranking <- order(
    -candidates$fit_score,
    candidates$detour_m,
    candidates$route_distance_m,
    tolower(candidates$name),
    candidates$venue_id
  )
  candidates <- candidates[ranking, , drop = FALSE]
  candidates$recommend_rank <- seq_len(nrow(candidates))
  rownames(candidates) <- NULL
  candidates
}

# Public candidate pipeline: validate -> project -> filter -> choose leg -> score -> rank.
# route_distance_m is nearest distance to ANY leg; offset_m is distance to the CHOSEN insertion
# leg. They can differ when several legs qualify for one venue.
# The pipeline projects venues, selects eligible legs, scores candidates and ranks them.
# route_distance_m measures the closest leg; offset_m measures the chosen insertion leg.
core_route_recommendations <- function(
  data,
  model,
  radius_m = 300,
  target = 0.5,
  mode = "balanced",
  category = "all"
) {
  if (length(radius_m) != 1L || !is.finite(radius_m) || radius_m <= 0) {
    stop("Route radius must be positive metres.")
  }
  if (length(target) != 1L || !is.finite(target) || target < 0 || target > 1) {
    stop("Meal position must be between zero and one.")
  }
  weights <- core_route_weights(mode)
  venues <- core_venues(
    data,
    category_codes = if (identical(category, "all")) {
      NULL
    } else {
      category
    }
  )
  if (!nrow(venues)) {
    return(core_empty_route_results(data))
  }

  points <- core_route_project(venues$longitude, venues$latitude, model$origin)
  metrics <- core_route_leg_metrics(points, model)
  nearest_distance <- apply(metrics$offsets, 1, min)
  rows <- which(nearest_distance <= radius_m + ROUTE_RADIUS_TOLERANCE_M)
  if (!length(rows)) {
    return(core_empty_route_results(data))
  }

  chosen_columns <- core_route_choose_legs(
    metrics,
    model,
    rows,
    radius_m,
    target
  )
  indices <- cbind(rows, chosen_columns)
  candidates <- venues[rows, , drop = FALSE]
  candidates$route_distance_m <- nearest_distance[rows]
  candidates$offset_m <- metrics$offsets[indices]
  candidates$detour_m <- metrics$detours[indices]
  candidates$progress <- metrics$positions[indices]
  candidates$leg <- model$legs[chosen_columns]
  projection <- core_route_unproject(
    metrics$projection_x[indices],
    metrics$projection_y[indices],
    model$origin
  )
  candidates$projection_lon <- projection[, 1]
  candidates$projection_lat <- projection[, 2]

  core_route_rank(core_route_score(candidates, radius_m, target, weights))
}

core_route_corridor <- function(model, radius_m) {
  features <- lapply(
    model$legs,
    function(leg_index) {
      start <- model$xy[leg_index, ]
      end <- model$xy[leg_index + 1L, ]
      angle <- atan2(end[2] - start[2], end[1] - start[1])
      back_angles <- seq(angle + pi / 2, angle + 3 * pi / 2, length.out = 17)
      front_angles <- seq(angle - pi / 2, angle + pi / 2, length.out = 17)
      x <- c(
        start[1] + radius_m * cos(back_angles),
        end[1] + radius_m * cos(front_angles)
      )
      y <- c(
        start[2] + radius_m * sin(back_angles),
        end[2] + radius_m * sin(front_angles)
      )
      ring <- core_route_unproject(
        c(x, x[1]),
        c(y, y[1]),
        model$origin
      )
      list(
        type = "Feature",
        properties = list(leg = leg_index),
        geometry = list(
          type = "Polygon",
          coordinates = list(
            lapply(
              seq_len(nrow(ring)),
              function(row) unname(ring[row, ])
            )
          )
        )
      )
    }
  )
  list(type = "FeatureCollection", features = features)
}

# Scene coordinates follow Leaflet's [latitude, longitude] order; GeoJSON uses [longitude,
# latitude]. All venue selection IDs remain canonical census IDs.
core_route_scene <- function(model, candidates, radius_m, selected = NULL) {
  corridor <- core_route_corridor(model, radius_m)
  markers <- core_venue_markers(candidates)
  stop_markers <- lapply(
    seq_len(nrow(model$nodes)),
    function(index) {
      node <- model$nodes[index, ]
      list(
        id = paste0("route-stop-", index),
        latitude = node$latitude,
        longitude = node$longitude,
        title = paste(index, node$name, sep = " · "),
        role = "landmark",
        label = as.character(index),
        tone = "landmark",
        emphasis = TRUE
      )
    }
  )
  markers <- c(markers, stop_markers)
  line <- lapply(
    seq_len(nrow(model$nodes)),
    function(index) {
      unname(c(model$nodes$latitude[index], model$nodes$longitude[index]))
    }
  )
  chosen <- candidates[candidates$venue_id %in% selected, , drop = FALSE]
  detour <- list()
  if (nrow(chosen) == 1L) {
    leg_index <- chosen$leg
    detour <- list(
      list(
        points = list(
          unname(c(
            model$nodes$latitude[leg_index],
            model$nodes$longitude[leg_index]
          )),
          unname(c(chosen$latitude, chosen$longitude)),
          unname(c(
            model$nodes$latitude[leg_index + 1L],
            model$nodes$longitude[leg_index + 1L]
          ))
        ),
        tone = "selection",
        dashed = TRUE
      )
    )
  }
  list(
    scope = paste(
      paste(model$ids, collapse = "/"),
      radius_m,
      paste(
        sort(candidates$venue_id),
        collapse = ":"
      ),
      sep = "|"
    ),
    markers = markers,
    selected = selected,
    corridor = corridor,
    lines = list(list(points = line, tone = "route")),
    selection_lines = detour,
    bounds = core_geo_bounds(corridor$features)
  )
}
