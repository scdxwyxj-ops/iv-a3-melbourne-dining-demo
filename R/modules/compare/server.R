compare_results <- function(data, a_id, b_id, radius, category = "all") {
  a <- venues_near(data, a_id, radius)
  b <- venues_near(data, b_id, radius)
  if (category != "all") {
    a <- a[a$category_code == category, , drop = FALSE]
    b <- b[b$category_code == category, , drop = FALSE]
  }
  shared <- intersect(a$venue_id, b$venue_id)
  ids <- union(a$venue_id, b$venue_id)
  venues <- core_venues(data, ids = ids)
  venues$distance_a <- a$distance_m[match(ids, a$venue_id)]
  venues$distance_b <- b$distance_m[match(ids, b$venue_id)]
  venues$membership <- ifelse(
    ids %in% shared,
    "shared",
    ifelse(ids %in% a$venue_id, "a", "b")
  )
  list(a = a, b = b, shared = shared, venues = venues)
}
compare_server <- function(id, data, state) {
  moduleServer(
    id,
    function(input, output, session) {
      selected_id <- reactiveVal(NULL)
      card_collapsed <- reactiveVal(FALSE)
      observeEvent(
        input$landmark_a,
        {
          req(input$landmark_a %in% core_landmarks(data)$poi_id)
          state$comparison_a_id <- input$landmark_a
        }
      )
      observeEvent(
        input$landmark_b,
        {
          req(input$landmark_b %in% core_landmarks(data)$poi_id)
          state$comparison_b_id <- input$landmark_b
        }
      )
      observeEvent(
        input$radius,
        {
          radius <- suppressWarnings(as.numeric(input$radius))
          req(
            length(radius) == 1L,
            is.finite(radius),
            radius >= app_settings()$compare$radius_min_m,
            radius <= app_settings()$compare$radius_max_m
          )
          state$comparison_radius_m <- radius
        }
      )
      result <- reactive({
        category <- input$category
        if (is.null(category)) {
          category <- "all"
        }
        req(category %in% c("all", "4511", "4512"))
        compare_results(
          data,
          state$comparison_a_id,
          state$comparison_b_id,
          state$comparison_radius_m,
          category
        )
      })
      origins <- reactive(
        rbind(
          get_landmark(data, state$comparison_a_id),
          get_landmark(data, state$comparison_b_id)
        )
      )
      output$notice <- renderUI({
        if (state$comparison_a_id == state$comparison_b_id) {
          p(
            class = "compare-notice",
            "Same landmark selected twice: both counts match and every result is shared."
          )
        } else if (!nrow(result()$venues)) {
          p(
            class = "compare-notice",
            "Choose All dining or increase the radius to explore venues."
          )
        }
      })
      output$counts <- renderUI({
        comparison <- result()
        origins <- origins()
        tagList(
          div(
            class = "compare-totals",
            div(
              class = "compare-total",
              strong(nrow(comparison$a)),
              span("Near A")
            ),
            div(
              class = "compare-total b",
              strong(nrow(comparison$b)),
              span("Near B")
            )
          ),
          div(
            class = "compare-overlap",
            div(
              class = "compare-venn",
              `aria-hidden` = "true",
              tags$i(),
              tags$i()
            ),
            div(
              strong(
                paste(
                  length(comparison$shared),
                  "venues in both areas"
                )
              ),
              p(paste(
                "Within",
                state$comparison_radius_m,
                "m of both landmarks."
              ))
            )
          )
        )
      })
      output$insight <- renderUI({
        comparison <- result()
        delta <- nrow(comparison$b) -
          nrow(comparison$a)
        origins <- origins()
        message <- if (delta == 0) {
          "Both places have the same number of matching venues."
        } else {
          paste(
            abs(delta),
            "more venues near",
            paste0(
              origins$name[
                if (delta > 0) {
                  2
                } else {
                  1
                }
              ],
              "."
            )
          )
        }
        div(
          class = "compare-insight",
          icon("chart-simple"),
          " ",
          message
        )
      })
      output$map_scope <- renderUI(span(
        class = "compare-scope",
        paste(state$comparison_radius_m, "m radius")
      ))
      map_scene <- reactive({
        comparison <- result()
        origins <- origins()
        radius <- state$comparison_radius_m
        markers <- core_venue_markers(
          comparison$venues,
          colour_by = "catchment"
        )
        markers <- c(
          markers,
          lapply(
            1:2,
            function(i) {
              list(
                id = paste0("landmark-", i),
                latitude = origins$latitude[i],
                longitude = origins$longitude[i],
                title = origins$name[i],
                role = "landmark",
                label = c("A", "B")[i],
                emphasis = TRUE,
                permanentLabel = TRUE,
                tone = "landmark"
              )
            }
          )
        )
        lat_pad <- radius / 111000 * 1.25
        lon_pad <- lat_pad /
          cos(
            mean(origins$latitude) *
              pi /
              180
          )
        list(
          scope = paste(
            state$comparison_a_id,
            state$comparison_b_id,
            radius,
            input$category,
            sep = "|"
          ),
          markers = markers,
          selected = selected_id(),
          circles = lapply(
            1:2,
            function(i) {
              list(
                latitude = origins$latitude[i],
                longitude = origins$longitude[i],
                radius = radius,
                tone = c("primary", "secondary")[i]
              )
            }
          ),
          bounds = list(
            c(
              min(origins$latitude) -
                lat_pad,
              min(origins$longitude) -
                lon_pad
            ),
            c(
              max(origins$latitude) +
                lat_pad,
              max(origins$longitude) +
                lon_pad
            )
          )
        )
      })
      observe({
        req(isTRUE(input$map_ready))
        core_map_render(session, "map", map_scene())
      })
      observeEvent(
        input$recenter,
        {
          core_map_fit(session, "map", map_scene()$bounds)
        }
      )
      observeEvent(
        input$explore,
        {
          showModal(
            modalDialog(
              title = "Explore venues",
              size = "l",
              easyClose = TRUE,
              selectInput(
                session$ns("scope"),
                "Show venues",
                c(
                  `In both catchments` = "shared",
                  `Only near A` = "a",
                  `Only near B` = "b",
                  `Either catchment` = "all"
                ),
                selected = "shared"
              ),
              uiOutput(session$ns("list_note")),
              div(class = "compare-table", tableOutput(session$ns("venues"))),
              selectizeInput(
                session$ns("venue"),
                "Select a venue",
                choices = NULL
              ),
              actionButton(
                session$ns("select_venue"),
                "Use selected venue",
                class = "btn-primary"
              ),
              p(
                class = "help-copy",
                "Use selected venue shares this restaurant selection with the other pages."
              ),
              footer = modalButton("Back to map")
            )
          )
        }
      )
      output$chart <- renderUI({
        comparison <- result()
        codes <- c("4511", "4512")
        labels <- c("Cafes & restaurants", "Takeaway")
        a <- vapply(
          codes,
          function(x) sum(comparison$a$category_code == x),
          integer(1)
        )
        b <- vapply(
          codes,
          function(x) sum(comparison$b$category_code == x),
          integer(1)
        )
        scale <- max(1, a, b)
        tagList(
          lapply(
            seq_along(codes),
            function(i) {
              div(
                class = "compare-chart-group",
                h3(labels[i]),
                lapply(
                  seq_len(2),
                  function(j) {
                    value <- if (j == 1) {
                      a[i]
                    } else {
                      b[i]
                    }
                    div(
                      class = "compare-bar-row",
                      span(c("A", "B")[j]),
                      div(
                        class = "compare-bar-track",
                        div(
                          class = paste("compare-bar", c("bar-a", "bar-b")[j]),
                          style = paste0("width:", 100 * value / scale, "%;")
                        )
                      ),
                      strong(value)
                    )
                  }
                )
              )
            }
          ),
          p(class = "help-copy", paste("Shared scale: 0 to", scale, "venues."))
        )
      })
      listed <- reactive({
        venues <- result()$venues
        scope <- input$scope
        if (is.null(scope)) {
          scope <- "shared"
        }
        if (scope != "all") {
          venues <- venues[venues$membership == scope, , drop = FALSE]
        }
        venues[order(venues$name, venues$venue_id), , drop = FALSE]
      })
      output$list_note <- renderUI({
        n <- nrow(listed())
        p(
          class = "help-copy",
          if (!n) {
            "Choose another group or increase the radius to explore venues."
          } else {
            paste(
              n,
              "venues. Table shows the first",
              min(n, 100),
              "alphabetically; the selector includes all results. A dash means outside that catchment."
            )
          }
        )
      })
      output$venues <- renderTable(
        {
          venues <- head(listed(), 100)
          data.frame(
            Venue = venues$name,
            Address = venues$address,
            `A distance (m)` = ifelse(
              is.na(venues$distance_a),
              "-",
              round(venues$distance_a)
            ),
            `B distance (m)` = ifelse(
              is.na(venues$distance_b),
              "-",
              round(venues$distance_b)
            ),
            check.names = FALSE
          )
        },
        striped = TRUE,
        spacing = "s",
        sanitize.text.function = htmltools::htmlEscape
      )
      observe({
        input$explore
        venues <- listed()
        updateSelectizeInput(
          session,
          "venue",
          choices = stats::setNames(
            venues$venue_id,
            paste(venues$name, venues$address, venues$venue_id, sep = " · ")
          ),
          selected = character(0),
          server = TRUE
        )
      })
      observeEvent(
        input$select_venue,
        {
          req(input$venue %in% listed()$venue_id)
          state$selected_venue_id <- input$venue
          selected_id(input$venue)
          card_collapsed(FALSE)
          removeModal()
        }
      )
      observeEvent(
        input$map_marker_click,
        {
          selected <- input$map_marker_click$id
          req(selected %in% result()$venues$venue_id)
          state$selected_venue_id <- selected
          selected_id(selected)
          card_collapsed(FALSE)
        }
      )
      # Filter/origin changes rebuild the map. Clear local selection to prevent stale cards.
      observeEvent(
        result(),
        {
          selected_id(NULL)
          card_collapsed(FALSE)
        }
      )
      observeEvent(
        input$card_toggle,
        {
          card_collapsed(!card_collapsed())
        }
      )
      observeEvent(
        input$card_close,
        {
          if (identical(state$selected_venue_id, selected_id())) {
            state$selected_venue_id <- NULL
          }
          selected_id(NULL)
          card_collapsed(FALSE)
        }
      )
      selected_venue <- reactive({
        id <- selected_id()
        venues <- result()$venues
        if (is.null(id)) {
          return(venues[FALSE, , drop = FALSE])
        }
        venues[venues$venue_id == id, , drop = FALSE]
      })
      output$venue_card <- renderUI({
        venues <- selected_venue()
        if (!nrow(venues)) {
          return(NULL)
        }
        origins <- origins()
        distances <- haversine_m(
          origins$longitude,
          origins$latitude,
          venues$longitude,
          venues$latitude
        )
        div(
          class = paste(
            "compare-venue-card",
            if (card_collapsed()) {
              "is-collapsed"
            } else {
              ""
            }
          ),
          role = "region",
          `aria-label` = "Selected restaurant",
          `aria-live` = "polite",
          div(
            class = "compare-card-header",
            div(
              span(class = "compare-card-eyebrow", "SELECTED VENUE"),
              h3(venues$name)
            ),
            actionButton(
              session$ns("card_toggle"),
              if (card_collapsed()) {
                "+"
              } else {
                "−"
              },
              title = if (card_collapsed()) {
                "Expand"
              } else {
                "Collapse"
              },
              `aria-expanded` = if (card_collapsed()) {
                "false"
              } else {
                "true"
              }
            ),
            actionButton(
              session$ns("card_close"),
              "×",
              title = "Close and deselect",
              `aria-label` = "Close and deselect"
            )
          ),
          if (!card_collapsed()) {
            div(
              class = "compare-card-body",
              p(class = "compare-card-category", venues$category),
              p(class = "compare-card-address", venues$address),
              div(
                class = "compare-card-distances",
                span(
                  paste(
                    "A ·",
                    round(distances[1]),
                    "m"
                  )
                ),
                span(
                  paste(
                    "B ·",
                    round(distances[2]),
                    "m"
                  )
                )
              ),
              p(
                class = "compare-card-description",
                switch(
                  venues$membership,
                  a = "Within A's search area only.",
                  b = "Within B's search area only.",
                  shared = "Within both search areas."
                )
              ),
              tags$small("Straight-line distance · 2024 census record")
            )
          }
        )
      })
    }
  )
}
