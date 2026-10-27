# Shared by R SVG builders and browser pointer/keyboard calculations.  Dimensions are SVG view-box
# units; radius values are metres.
nearby_chart_layout <- function() {
  config <- app_settings()$nearby
  c(config[c("radius_min_m", "radius_max_m", "radius_step_m")], config$chart)
}

nearby_chart_text <- function(x, y, label, ...) {
  tags$text(x = x, y = y, ..., label)
}
nearby_chart_axes <- function(
  x_at,
  x_labels,
  y_at,
  y_labels,
  x_title,
  y_title,
  layout = nearby_chart_layout()
) {
  tagList(
    lapply(
      seq_along(y_at),
      function(i) {
        tagList(
          tags$line(
            x1 = layout$plot_left,
            y1 = y_at[i],
            x2 = layout$plot_right,
            y2 = y_at[i],
            class = "nearby-chart-grid"
          ),
          nearby_chart_text(54, y_at[i] + 4, y_labels[i], `text-anchor` = "end")
        )
      }
    ),
    lapply(
      seq_along(x_at),
      function(i) {
        nearby_chart_text(x_at[i], 304, x_labels[i], `text-anchor` = "middle")
      }
    ),
    tags$line(
      x1 = layout$plot_left,
      y1 = layout$plot_bottom,
      x2 = layout$plot_right,
      y2 = layout$plot_bottom,
      class = "nearby-chart-axis"
    ),
    nearby_chart_text(
      330,
      335,
      x_title,
      `text-anchor` = "middle",
      class = "nearby-axis-title"
    ),
    nearby_chart_text(65, 16, y_title, class = "nearby-axis-title")
  )
}
nearby_chart_ticks <- function(maximum) {
  limit <- max(1, maximum)
  if (limit <= 5) {
    seq(0, ceiling(limit))
  } else {
    pretty(
      c(0, limit),
      n = 4
    )
  }
}

# Cumulative venue counts across the complete radius range.
nearby_radius_chart <- function(venues, radius, current_n, namespace) {
  layout <- nearby_chart_layout()
  distances <- sort(venues$distance_m)
  xs <- unique(distances)
  counts <- findInterval(xs, distances)
  ticks <- nearby_chart_ticks(nrow(venues))
  ticks <- ticks[ticks >= 0]
  ymax <- max(ticks)
  x <- function(v) {
    layout$plot_left +
      v / layout$radius_max_m * layout$plot_width
  }
  y <- function(v) {
    layout$plot_bottom -
      v / ymax * layout$plot_height
  }
  commands <- c(
    sprintf(
      "M %.3f %.3f",
      x(0),
      y(0)
    ),
    sprintf(
      "H %.3f V %.3f",
      x(xs),
      y(counts)
    ),
    sprintf("H %.3f", x(layout$radius_max_m))
  )
  previews <- vapply(
    seq(0, layout$radius_max_m, layout$radius_step_m),
    function(r) sum(distances <= r),
    integer(1)
  )
  tagList(
    tags$svg(
      viewBox = paste(0, 0, layout$view_width, layout$view_height),
      class = "nearby-chart nearby-curve-svg",
      role = "group",
      `aria-label` = "Cumulative dining venue counts from zero to 1200 metres",
      tags$rect(
        x = x(0),
        y = 28,
        width = x(radius) -
          x(0),
        height = 254,
        class = "nearby-curve-area"
      ),
      nearby_chart_axes(
        x(seq(0, layout$radius_max_m, 200)),
        seq(0, layout$radius_max_m, 200),
        y(ticks),
        ticks,
        "Straight-line distance (m)",
        "Venues within distance"
      ),
      tags$path(
        d = paste(commands, collapse = " "),
        class = "nearby-curve-line"
      ),
      tags$line(
        x1 = x(radius),
        x2 = x(radius),
        y1 = 28,
        y2 = 282,
        class = "nearby-radius-guide"
      ),
      tags$circle(
        cx = x(radius),
        cy = y(current_n),
        r = 5,
        class = "nearby-radius-dot"
      ),
      nearby_chart_text(
        x(radius) +
          if (radius > 850) {
            -9
          } else {
            9
          },
        max(
          44,
          y(current_n) -
            12
        ),
        paste(radius, "m ·", current_n, "venues"),
        `text-anchor` = if (radius > 850) {
          "end"
        } else {
          "start"
        },
        class = "nearby-current-label"
      ),
      tags$rect(
        x = layout$plot_left,
        y = layout$plot_top,
        width = layout$plot_width,
        height = layout$hit_height,
        fill = "transparent",
        class = "nearby-radius-hit",
        tabindex = 0,
        role = "slider",
        `aria-label` = "Search radius on cumulative chart",
        `aria-valuemin` = layout$radius_min_m,
        `aria-valuemax` = layout$radius_max_m,
        `aria-valuenow` = radius,
        `aria-valuetext` = paste(radius, "metres,", current_n, "venues"),
        `aria-describedby` = namespace("curve_hint"),
        `data-counts` = jsonlite::toJSON(previews),
        `data-radius` = radius
      )
    ),
    div(
      id = namespace("radius_preview"),
      class = "nearby-plot-readout",
      role = "status",
      paste(
        radius,
        "m ·",
        current_n,
        "venues · click the curve to change radius"
      )
    )
  )
}

# Unknown indoor seat counts are omitted from points, but retained in the inventory.
nearby_capacity_chart <- function(venues, radius, namespace) {
  layout <- nearby_chart_layout()
  known <- venues[!is.na(venues$indoor_seats), , drop = FALSE]
  missing <- nrow(venues) -
    nrow(known)
  if (!nrow(known)) {
    return(
      div(
        class = "nearby-empty",
        h3(
          if (!nrow(venues)) {
            "0 venues within this radius"
          } else {
            "Indoor capacity is unrecorded"
          }
        ),
        p(
          if (!nrow(venues)) {
            "Increase the radius to explore more options."
          } else {
            "These venues remain available in the map and list."
          }
        )
      )
    )
  }
  ticks <- nearby_chart_ticks(max(known$indoor_seats))
  ticks <- ticks[ticks >= 0]
  ymax <- max(ticks)
  x <- function(v) {
    layout$plot_left +
      v / radius * layout$plot_width
  }
  y <- function(v) {
    layout$plot_bottom -
      v / ymax * layout$plot_height
  }
  xticks <- unique(
    c(
      seq(0, radius, by = if (radius <= 600) 100 else 200),
      radius
    )
  )
  tagList(
    tags$svg(
      viewBox = paste(0, 0, layout$view_width, layout$view_height),
      class = "nearby-chart nearby-scatter-svg",
      role = "group",
      `aria-label` = "Compare nearby venue distance and recorded indoor capacity",
      nearby_chart_axes(
        x(xticks),
        xticks,
        y(ticks),
        ticks,
        "Straight-line distance (m)",
        "Recorded indoor seats"
      ),
      lapply(
        seq_len(nrow(known)),
        function(i) {
          v <- known[i, ]
          tags$circle(
            cx = x(v$distance_m),
            cy = y(v$indoor_seats),
            r = 4.5,
            class = paste(
              "nearby-scatter-point",
              if (v$category_code == "4512") {
                "takeaway"
              } else {
                "cafe"
              }
            ),
            `data-venue-id` = v$venue_id,
            `data-position` = sprintf("%.9f:%s", v$distance_m, v$indoor_seats),
            tabindex = if (i == 1) {
              0
            } else {
              -1
            },
            role = "button",
            `aria-pressed` = "false",
            `aria-label` = paste(
              v$name,
              round(v$distance_m),
              "metres,",
              v$indoor_seats,
              "recorded indoor seats"
            ),
            tags$title(
              paste(
                v$name,
                "·",
                round(v$distance_m),
                "m ·",
                v$indoor_seats,
                "indoor seats"
              )
            )
          )
        }
      )
    ),
    div(
      id = namespace("point_readout"),
      class = "nearby-plot-readout",
      role = "status",
      "Hover for venue details. Select a point to link it to the map and list."
    ),
    div(
      id = namespace("point_choices"),
      class = "nearby-point-choices",
      role = "group",
      `aria-label` = "Overlapping venues in capacity plot"
    ),
    p(
      class = "nearby-data-note",
      paste(
        nrow(known),
        "of",
        nrow(venues),
        "venues plotted ·",
        missing,
        "with unrecorded indoor seats remain in the map and list. Seating capacity is recorded in the 2024 census."
      )
    )
  )
}
