route_ranked_ui <- function(venues, selected_venue_id) {
  total_candidates <- nrow(venues)
  venues <- head(venues, 5)
  if (!nrow(venues)) {
    return(
      div(
        class = "route-empty",
        h3("Choose a route to explore restaurants"),
        p("Add two different stops or widen the corridor.")
      )
    )
  }
  tagList(
    p(
      class = "route-help",
      paste(
        "Top",
        nrow(venues),
        "of",
        total_candidates,
        "eligible venues"
      )
    ),
    lapply(
      seq_len(nrow(venues)),
      function(i) {
        row <- venues[i, ]
        active <- identical(row$venue_id, selected_venue_id)
        tags$button(
          type = "button",
          class = paste(
            "route-recommendation",
            if (active) {
              "is-selected"
            }
          ),
          `data-route-select` = row$venue_id,
          `aria-pressed` = if (active) {
            "true"
          } else {
            "false"
          },
          span(class = "route-rank", i),
          span(
            class = "route-recommendation-body",
            strong(row$name),
            span(
              class = "route-recommendation-meta",
              paste(
                "Leg",
                row$leg,
                "· +",
                round(row$detour_m),
                "m ·",
                round(100 * row$progress),
                "% through trip"
              )
            ),
            span(class = "route-recommendation-category", row$category)
          ),
          span(
            class = "route-fit",
            strong(round(row$fit_score)),
            span("plan fit /100")
          )
        )
      }
    )
  )
}

route_selection_ui <- function(venue, namespace) {
  venues <- venue
  if (nrow(venues) != 1L) {
    return(
      p(
        class = "route-selection-hint",
        "Choose a suggestion, a map point or a chart point to inspect why it fits."
      )
    )
  }
  contribution <- function(label, value) {
    div(
      class = "route-contribution",
      span(label),
      div(
        class = "route-contribution-track",
        span(style = paste0("width:", value, "%;"))
      ),
      strong(paste0("+", round(value, 1)))
    )
  }
  div(
    class = "route-selected",
    span(class = "route-selected-kicker", "Selected meal stop"),
    h3(venues$name),
    p(paste("Insert between stops", venues$leg, "and", venues$leg + 1L)),
    div(
      class = "route-selected-facts",
      span(
        strong(
          paste0(
            "+",
            round(venues$detour_m),
            " m"
          )
        ),
        "extra straight-line distance"
      ),
      span(
        strong(
          paste0(
            round(venues$offset_m),
            " m"
          )
        ),
        "offset from the suggested leg"
      )
    ),
    contribution("Detour contribution", venues$detour_component),
    contribution("Meal-position contribution", venues$position_component),
    p(
      class = "route-score-total",
      paste(
        "Plan-fit score:",
        round(venues$fit_score, 1),
        "/ 100"
      )
    ),
    actionButton(
      namespace("full_details"),
      "Full restaurant details",
      class = "btn-primary"
    )
  )
}

route_mix_ui <- function(venues) {
  venues <- venues
  counts <- c(
    sum(venues$category_code == "4511"),
    sum(venues$category_code == "4512")
  )
  total <- sum(counts)
  shares <- if (total) {
    counts / total
  } else {
    c(0, 0)
  }
  labels <- c("Cafés & restaurants", "Takeaway")
  classes <- c("cafe", "takeaway")
  slices <- lapply(
    which(counts > 0),
    function(i) {
      start <- -pi / 2 + 2 * pi * sum(shares[seq_len(i - 1L)])
      end <- start + 2 * pi * shares[i]
      title <- tags$title(
        paste0(
          labels[i],
          ": ",
          counts[i],
          " (",
          sprintf("%.1f", 100 * shares[i]),
          "%)"
        )
      )
      attributes <- list(
        class = paste("route-pie-slice", classes[i]),
        `data-category` = c("4511", "4512")[i],
        `data-count` = counts[i]
      )
      if (counts[i] == total) {
        return(
          do.call(
            tags$circle,
            c(
              list(cx = 100, cy = 100, r = 88),
              attributes,
              list(title)
            )
          )
        )
      }
      path <- sprintf(
        "M 100 100 L %.6f %.6f A 88 88 0 %d 1 %.6f %.6f Z",
        100 + 88 * cos(start),
        100 + 88 * sin(start),
        as.integer(shares[i] > 0.5),
        100 + 88 * cos(end),
        100 + 88 * sin(end)
      )
      do.call(
        tags$path,
        c(
          list(d = path),
          attributes,
          list(title)
        )
      )
    }
  )
  div(
    class = "route-mix",
    h3("Venue mix"),
    div(
      class = "route-mix-layout",
      tags$svg(
        viewBox = "0 0 200 200",
        class = "route-mix-pie",
        role = "img",
        `aria-label` = if (total) {
          paste(
            counts[1],
            "cafés and restaurants and",
            counts[2],
            "takeaway venues out of",
            total,
            "candidates"
          )
        } else {
          "0 candidate venues"
        },
        if (total) {
          slices
        } else {
          tagList(
            tags$circle(cx = 100, cy = 100, r = 88, class = "route-pie-empty"),
            tags$text(x = 100, y = 104, `text-anchor` = "middle", "0 venues")
          )
        }
      ),
      div(
        class = "route-mix-legend",
        lapply(
          1:2,
          function(i) {
            div(
              class = "route-mix-row",
              span(class = paste("legend-dot", classes[i])),
              div(
                span(class = "route-mix-name", labels[i]),
                span(
                  class = "route-mix-share",
                  if (total) {
                    paste0(
                      sprintf("%.1f", 100 * shares[i]),
                      "% of candidates"
                    )
                  } else {
                    "0 candidates"
                  }
                )
              ),
              strong(counts[i])
            )
          }
        )
      )
    )
  )
}

route_distribution_ui <- function(venues, route, selected_venue_id) {
  venues <- venues
  route <- route
  if (
    is.null(route) ||
      !nrow(venues)
  ) {
    return(p(
      class = "route-help",
      "The distribution appears when the itinerary has candidate venues."
    ))
  }
  x <- function(progress) {
    155 +
      progress * 460
  }
  lane <- ifelse(venues$category_code == "4512", 120, 65)
  jitter <- (seq_len(nrow(venues)) %% 5 - 2) * 4
  tagList(
    div(
      class = "route-chart-scroll",
      tags$svg(
        viewBox = "0 0 640 205",
        class = "route-distribution",
        role = "group",
        `aria-label` = "Dining venues along the ordered route",
        tags$text(x = 8, y = 68, "Cafés/restaurants"),
        tags$text(x = 8, y = 123, "Takeaway"),
        tags$line(
          x1 = 155,
          x2 = 615,
          y1 = 155,
          y2 = 155,
          class = "route-chart-axis"
        ),
        lapply(
          seq_len(nrow(route$nodes)),
          function(i) {
            tagList(
              tags$line(
                x1 = x(route$cumulative[i] / route$total_m),
                x2 = x(route$cumulative[i] / route$total_m),
                y1 = 35,
                y2 = 160,
                class = "route-chart-guide"
              ),
              tags$text(
                x = x(route$cumulative[i] / route$total_m),
                y = 180,
                `text-anchor` = "middle",
                paste("Stop", i)
              )
            )
          }
        ),
        lapply(
          seq_len(nrow(venues)),
          function(i) {
            tags$circle(
              cx = x(venues$progress[i]),
              cy = lane[i] + jitter[i],
              r = if (venues$venue_id[i] %in% selected_venue_id) {
                5
              } else {
                3
              },
              class = paste(
                "route-chart-point",
                if (venues$category_code[i] == "4512") {
                  "takeaway"
                } else {
                  "cafe"
                },
                if (venues$venue_id[i] %in% selected_venue_id) {
                  "is-selected"
                }
              ),
              `data-route-select` = venues$venue_id[i],
              tabindex = if (i == 1L) {
                0
              } else {
                -1
              },
              role = "button",
              `aria-label` = paste(
                venues$name[i],
                "leg",
                venues$leg[i],
                "extra",
                round(venues$detour_m[i]),
                "metres"
              ),
              tags$title(venues$name[i])
            )
          }
        )
      )
    ),
    p(
      class = "route-help",
      "Placement uses the selected insertion leg. Shared locations can contain several venue records; list and map selectors retain their identities."
    )
  )
}
