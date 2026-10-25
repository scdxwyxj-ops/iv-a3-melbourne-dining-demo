# Feature 2 owns nearby settings and venue selection; feature 4 owns saved IDs.
# AI-assisted view upgrade, OpenAI Codex, 2026-10-25. See docs/STARTER_AI_USAGE.md.
nearby_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$landmark, {
      req(length(input$landmark) == 1L, input$landmark %in% data$landmarks$poi_id)
      state$landmark_id <- input$landmark
    })
    observeEvent(input$radius, {
      req(is.numeric(input$radius), length(input$radius) == 1L,
          is.finite(input$radius), input$radius >= 200, input$radius <= 1200)
      state$radius_m <- as.numeric(input$radius)
    })
    # The curve previews the complete allowed range; all other views use the radius.
    context_venues <- reactive({ venues_near(data, state$landmark_id, 1200) })
    nearby_venues <- reactive({
      venues <- context_venues()
      venues[venues$distance_m <= state$radius_m, , drop = FALSE]
    })
    observeEvent(input$chart_radius, {
      value <- input$chart_radius
      req(is.numeric(value), length(value) == 1L, is.finite(value), value >= 200, value <= 1200)
      value <- floor(value / 100 + 0.5) * 100
      state$radius_m <- value
      updateSliderInput(session, "radius", value = value)
    })

    # Clear a selection only when a changed catchment no longer contains it.
    observeEvent(nearby_venues(), {
      if (!is.null(state$selected_venue_id) && !state$selected_venue_id %in% nearby_venues()$venue_id) {
        state$selected_venue_id <- NULL
      }
    })
    observeEvent(input$select_venue, {
      selected <- input$select_venue
      req(is.character(selected), length(selected) == 1L, selected %in% nearby_venues()$venue_id)
      state$selected_venue_id <- selected
    })
    observeEvent(input$clear_selection, { state$selected_venue_id <- NULL })
    observeEvent(input$show_on_map, {
      req(state$selected_venue_id %in% nearby_venues()$venue_id)
      updateTabsetPanel(session, "view", selected = "map")
      session$sendCustomMessage(session$ns("reveal_selection"), list())
    })

    output$count <- renderUI({
      venues <- nearby_venues()
      stat <- function(value, label) div(class = "nearby-stat",
        strong(class = "nearby-summary-number", value), span(label))
      div(class = "nearby-overview",
        metric_card(nrow(venues), paste("venues within", state$radius_m, "m")),
        stat(sum(venues$category_code == "4511"), "Cafés & restaurants"),
        stat(sum(venues$category_code == "4512"), "Takeaway"),
        stat(if (nrow(venues)) paste(round(min(venues$distance_m)), "m") else "—", "Nearest recorded venue"))
    })
    output$map_caption <- renderUI({
      origin <- get_landmark(data, state$landmark_id)
      p(class = "nearby-map-caption", strong(origin$name), span(paste(" ·", state$radius_m, "m radius")))
    })
    output$list <- renderUI({
      venues <- nearby_venues()
      if (!nrow(venues)) {
        return(div(class = "nearby-empty", h3("No venues within this radius"),
          p("Increase the radius or choose another landmark.")))
      }
      tagList(lapply(seq_len(nrow(venues)), function(i) {
        venue <- venues[i, ]
        tags$button(type = "button", class = "nearby-venue", `data-venue-id` = venue$venue_id,
          `aria-pressed` = "false",
          span(class = "nearby-venue-top", strong(class = "nearby-venue-name", venue$name),
            span(class = "nearby-distance", paste(round(venue$distance_m), "m"))),
          span(class = "nearby-venue-category",
            span(class = paste("legend-dot", if (venue$category_code == "4512") "takeaway" else "cafe")), venue$category),
          span(class = "nearby-venue-address", venue$address))
      }))
    })
    output$selection <- renderUI({
      venue <- nearby_venues()
      venue <- venue[venue$venue_id %in% state$selected_venue_id, , drop = FALSE]
      if (nrow(venue) != 1L) {
        return(p(class = "help-copy", "Select a map marker, a result or a capacity point. Your selection stays linked across views."))
      }
      seats <- function(value) if (is.na(value)) "Unrecorded" else format(value, trim = TRUE)
      tagList(
        strong(class = "nearby-selected-name", venue$name),
        p(class = "nearby-selected-meta", venue$category),
        p(class = "help-copy", venue$address),
        p(class = "nearby-selected-distance", paste(round(venue$distance_m), "m from the landmark")),
        div(class = "nearby-seat-summary",
          div(span("Indoor seats"), strong(seats(venue$indoor_seats))),
          div(span("Outdoor seats"), strong(seats(venue$outdoor_seats)))),
        if (is.na(venue$indoor_seats)) p(class = "nearby-data-note", "Indoor capacity is unrecorded, so this venue is not plotted in the capacity chart."),
        div(class = "nearby-selection-actions",
          actionButton(session$ns("show_on_map"), "Show on map", class = "btn-primary"),
          actionButton(session$ns("clear_selection"), "Clear selection", class = "btn-default nearby-clear"))
      )
    })

    # SVG charts inherit the interface font. Source strings are escaped by tags.
    svg_text <- function(x, y, label, ...) tags$text(x = x, y = y, ..., label)
    axes <- function(x_at, x_labels, y_at, y_labels, x_title, y_title) {
      tagList(
        lapply(seq_along(y_at), function(i) tagList(
          tags$line(x1 = 65, y1 = y_at[i], x2 = 596, y2 = y_at[i], class = "nearby-chart-grid"),
          svg_text(54, y_at[i] + 4, y_labels[i], `text-anchor` = "end"))),
        lapply(seq_along(x_at), function(i) svg_text(x_at[i], 304, x_labels[i], `text-anchor` = "middle")),
        tags$line(x1 = 65, y1 = 282, x2 = 596, y2 = 282, class = "nearby-chart-axis"),
        svg_text(330, 335, x_title, `text-anchor` = "middle", class = "nearby-axis-title"),
        svg_text(65, 16, y_title, class = "nearby-axis-title"))
    }
    chart_ticks <- function(maximum) {
      limit <- max(1, maximum)
      if (limit <= 5) seq(0, ceiling(limit)) else pretty(c(0, limit), n = 4)
    }
    output$curve <- renderUI({
      venues <- context_venues()
      distances <- sort(venues$distance_m)
      xs <- unique(distances)
      counts <- findInterval(xs, distances)
      ticks <- chart_ticks(nrow(venues))
      ticks <- ticks[ticks >= 0]
      ymax <- max(ticks)
      x <- function(v) 65 + v / 1200 * 531
      y <- function(v) 282 - v / ymax * 250
      commands <- c(sprintf("M %.3f %.3f", x(0), y(0)),
        sprintf("H %.3f V %.3f", x(xs), y(counts)), sprintf("H %.3f", x(1200)))
      radius <- state$radius_m
      current_n <- nrow(nearby_venues())
      previews <- vapply(seq(0, 1200, 100), function(r) sum(distances <= r), integer(1))
      tagList(
        tags$svg(viewBox = "0 0 620 350", class = "nearby-chart nearby-curve-svg", role = "group",
          `aria-label` = "Cumulative dining venue counts from zero to 1200 metres",
          tags$rect(x = x(0), y = 28, width = x(radius) - x(0), height = 254, class = "nearby-curve-area"),
          axes(x(seq(0, 1200, 200)), seq(0, 1200, 200), y(ticks), ticks,
            "Straight-line distance (m)", "Venues within distance"),
          tags$path(d = paste(commands, collapse = " "), class = "nearby-curve-line"),
          tags$line(x1 = x(radius), x2 = x(radius), y1 = 28, y2 = 282, class = "nearby-radius-guide"),
          tags$circle(cx = x(radius), cy = y(current_n), r = 5, class = "nearby-radius-dot"),
          svg_text(x(radius) + if (radius > 850) -9 else 9, max(44, y(current_n) - 12),
            paste(radius, "m ·", current_n, "venues"),
            `text-anchor` = if (radius > 850) "end" else "start", class = "nearby-current-label"),
          tags$rect(x = 65, y = 28, width = 531, height = 254, fill = "transparent",
            class = "nearby-radius-hit", tabindex = 0, role = "slider",
            `aria-label` = "Search radius on cumulative chart", `aria-valuemin` = 200,
            `aria-valuemax` = 1200, `aria-valuenow` = radius, `aria-valuetext` = paste(radius, "metres,", current_n, "venues"),
            `aria-describedby` = session$ns("curve_hint"),
            `data-counts` = jsonlite::toJSON(previews), `data-radius` = radius)),
        div(id = session$ns("radius_preview"), class = "nearby-plot-readout", role = "status",
          paste(radius, "m ·", current_n, "venues · click the curve to change radius"))
      )
    })
    output$scatter <- renderUI({
      venues <- nearby_venues()
      known <- venues[!is.na(venues$indoor_seats), , drop = FALSE]
      missing <- nrow(venues) - nrow(known)
      if (!nrow(known)) {
        return(div(class = "nearby-empty", h3(if (!nrow(venues)) "No venues within this radius" else "Indoor capacity is unrecorded"),
          p(if (!nrow(venues)) "Increase the radius to explore more options." else "These venues remain available in the map and list.")))
      }
      radius <- state$radius_m
      ticks <- chart_ticks(max(known$indoor_seats))
      ticks <- ticks[ticks >= 0]
      ymax <- max(ticks)
      x <- function(v) 65 + v / radius * 531
      y <- function(v) 282 - v / ymax * 250
      xticks <- unique(c(seq(0, radius, by = if (radius <= 600) 100 else 200), radius))
      tagList(
        tags$svg(viewBox = "0 0 620 350", class = "nearby-chart nearby-scatter-svg", role = "group",
          `aria-label` = "Compare nearby venue distance and recorded indoor capacity",
          axes(x(xticks), xticks, y(ticks), ticks, "Straight-line distance (m)", "Recorded indoor seats"),
          lapply(seq_len(nrow(known)), function(i) {
            v <- known[i, ]
            tags$circle(cx = x(v$distance_m), cy = y(v$indoor_seats), r = 4.5,
              class = paste("nearby-scatter-point", if (v$category_code == "4512") "takeaway" else "cafe"),
              `data-venue-id` = v$venue_id,
              `data-position` = sprintf("%.9f:%s", v$distance_m, v$indoor_seats),
              tabindex = if (i == 1) 0 else -1, role = "button", `aria-pressed` = "false",
              `aria-label` = paste(v$name, round(v$distance_m), "metres,", v$indoor_seats, "recorded indoor seats"),
              tags$title(paste(v$name, "·", round(v$distance_m), "m ·", v$indoor_seats, "indoor seats")))
          })),
        div(id = session$ns("point_readout"), class = "nearby-plot-readout", role = "status",
          "Hover for venue details. Select a point to link it to the map and list."),
        div(id = session$ns("point_choices"), class = "nearby-point-choices", role = "group", `aria-label` = "Overlapping venues in capacity plot"),
        p(class = "nearby-data-note", paste(nrow(known), "of", nrow(venues), "venues plotted ·", missing,
          "with unrecorded indoor seats remain in the map and list. Capacity is not live availability."))
      )
    })

    # Browser messages stay namespaced; public shared-state fields are unchanged.
    observe({
      req(isTRUE(input$map_ready))
      origin <- get_landmark(data, state$landmark_id)
      venues <- nearby_venues()
      fields <- c("venue_id", "name", "address", "category", "category_code", "longitude", "latitude",
                  "distance_m", "indoor_seats", "outdoor_seats")
      rows <- lapply(seq_len(nrow(venues)), function(i) as.list(venues[i, fields, drop = FALSE]))
      session$sendCustomMessage(session$ns("map_update"), list(
        scope = paste(state$landmark_id, state$radius_m, sep = ":"),
        origin = list(name = origin$name, longitude = origin$longitude, latitude = origin$latitude),
        radius = state$radius_m, venues = rows, selected = state$selected_venue_id
      ))
    })
  })
}
