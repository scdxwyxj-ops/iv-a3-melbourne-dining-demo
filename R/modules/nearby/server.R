# Nearby owns the landmark/radius filters. All active pages share the selected venue ID.
nearby_server <- function(id, data, state) {
  moduleServer(
    id,
    function(input, output, session) {
      chart_layout <- nearby_chart_layout()
      observeEvent(
        input$landmark,
        {
          req(
            length(input$landmark) == 1L,
            input$landmark %in% core_landmarks(data)$poi_id
          )
          state$landmark_id <- input$landmark
        }
      )
      observeEvent(
        input$radius,
        {
          req(
            is.numeric(input$radius),
            length(input$radius) == 1L,
            is.finite(input$radius),
            input$radius >= chart_layout$radius_min_m,
            input$radius <= chart_layout$radius_max_m
          )
          state$radius_m <- as.numeric(input$radius)
        }
      )
      # The curve previews the complete allowed range; all other views use the radius.
      context_venues <- reactive({
        venues_near(data, state$landmark_id, chart_layout$radius_max_m)
      })
      nearby_venues <- reactive({
        venues <- context_venues()
        venues[venues$distance_m <= state$radius_m, , drop = FALSE]
      })
      observeEvent(
        input$chart_radius,
        {
          value <- input$chart_radius
          req(
            is.numeric(value),
            length(value) == 1L,
            is.finite(value),
            value >= chart_layout$radius_min_m,
            value <= chart_layout$radius_max_m
          )
          value <- floor(value / chart_layout$radius_step_m + 0.5) *
            chart_layout$radius_step_m
          state$radius_m <- value
          updateSliderInput(session, "radius", value = value)
        }
      )

      observeEvent(
        nearby_venues(),
        {
          if (
            !is.null(state$selected_venue_id) &&
              !state$selected_venue_id %in% nearby_venues()$venue_id
          ) {
            state$selected_venue_id <- NULL
          }
        }
      )
      observeEvent(
        input$select_venue,
        {
          selected <- input$select_venue
          req(
            is.character(selected),
            length(selected) == 1L,
            selected %in% nearby_venues()$venue_id
          )
          state$selected_venue_id <- selected
        }
      )
      observeEvent(
        input$clear_selection,
        {
          state$selected_venue_id <- NULL
        }
      )
      observeEvent(
        input$show_on_map,
        {
          req(state$selected_venue_id %in% nearby_venues()$venue_id)
          updateTabsetPanel(session, "view", selected = "map")
          session$sendCustomMessage(
            session$ns("reveal_selection"),
            list()
          )
        }
      )

      output$count <- renderUI({
        venues <- nearby_venues()
        stat <- function(value, label) {
          div(
            class = "nearby-stat",
            strong(class = "nearby-summary-number", value),
            span(label)
          )
        }
        div(
          class = "nearby-overview",
          metric_card(
            nrow(venues),
            paste("venues within", state$radius_m, "m")
          ),
          stat(
            sum(venues$category_code == "4511"),
            "Cafés & restaurants"
          ),
          stat(
            sum(venues$category_code == "4512"),
            "Takeaway"
          ),
          stat(
            if (nrow(venues)) {
              paste(
                round(min(venues$distance_m)),
                "m"
              )
            } else {
              "—"
            },
            "Nearest recorded venue"
          )
        )
      })
      output$map_caption <- renderUI({
        origin <- get_landmark(data, state$landmark_id)
        p(
          class = "nearby-map-caption",
          strong(origin$name),
          span(paste(" ·", state$radius_m, "m radius"))
        )
      })
      output$list <- renderUI({
        venues <- nearby_venues()
        if (!nrow(venues)) {
          return(
            div(
              class = "nearby-empty",
              h3("0 venues within this radius"),
              p("Increase the radius or choose another landmark.")
            )
          )
        }
        tagList(
          lapply(
            seq_len(nrow(venues)),
            function(i) core_venue_card(venues[i, ], data)
          )
        )
      })
      observeEvent(
        input$full_details,
        {
          venue <- nearby_venues()
          venue <- venue[
            venue$venue_id %in% state$selected_venue_id,
            ,
            drop = FALSE
          ]
          req(
            nrow(venue) == 1L
          )
          showModal(
            modalDialog(
              title = "Restaurant details",
              size = "l",
              easyClose = TRUE,
              core_venue_detail_ui(
                venue,
                data,
                paste(
                  round(venue$distance_m),
                  "m from the selected landmark · straight line"
                )
              ),
              footer = modalButton("Back to nearby dining")
            )
          )
        }
      )
      output$selection <- renderUI({
        venue <- nearby_venues()
        venue <- venue[
          venue$venue_id %in% state$selected_venue_id,
          ,
          drop = FALSE
        ]
        if (nrow(venue) != 1L) {
          return(
            p(
              class = "help-copy",
              "Select a map marker, a result or a capacity point. Your selection stays linked across views."
            )
          )
        }
        seats <- function(value) {
          if (is.na(value)) {
            "—"
          } else {
            format(value, trim = TRUE)
          }
        }
        tagList(
          strong(class = "nearby-selected-name", venue$name),
          p(class = "nearby-selected-meta", venue$category),
          p(class = "help-copy", venue$address),
          p(
            class = "nearby-selected-distance",
            paste(
              round(venue$distance_m),
              "m from the landmark"
            )
          ),
          div(
            class = "nearby-seat-summary",
            div(
              span("Indoor seats"),
              strong(seats(venue$indoor_seats))
            ),
            div(
              span("Outdoor seats"),
              strong(seats(venue$outdoor_seats))
            )
          ),
          if (is.na(venue$indoor_seats)) {
            p(
              class = "nearby-data-note",
              "Indoor capacity is unrecorded, so this venue is source value in the capacity chart."
            )
          },
          div(
            class = "nearby-selection-actions",
            actionButton(
              session$ns("show_on_map"),
              "Show on map",
              class = "btn-primary"
            ),
            actionButton(
              session$ns("full_details"),
              "Full details",
              class = "btn-default"
            ),
            actionButton(
              session$ns("clear_selection"),
              "Clear selection",
              class = "btn-default nearby-clear"
            )
          )
        )
      })

      output$curve <- renderUI({
        nearby_radius_chart(
          context_venues(),
          state$radius_m,
          nrow(nearby_venues()),
          session$ns
        )
      })
      output$scatter <- renderUI({
        nearby_capacity_chart(nearby_venues(), state$radius_m, session$ns)
      })

      # Browser messages stay namespaced; public shared-state fields are unchanged.
      observe({
        req(isTRUE(input$map_ready))
        origin <- get_landmark(data, state$landmark_id)
        venues <- nearby_venues()
        fields <- c(
          "venue_id",
          "name",
          "address",
          "category",
          "category_code",
          "longitude",
          "latitude",
          "distance_m",
          "indoor_seats",
          "outdoor_seats"
        )
        rows <- lapply(
          seq_len(nrow(venues)),
          function(i) as.list(venues[i, fields, drop = FALSE])
        )
        session$sendCustomMessage(
          session$ns("map_update"),
          list(
            scope = paste(state$landmark_id, state$radius_m, sep = ":"),
            origin = list(
              name = origin$name,
              longitude = origin$longitude,
              latitude = origin$latitude
            ),
            radius = state$radius_m,
            venues = rows,
            selected = state$selected_venue_id
          )
        )
      })
    }
  )
}
