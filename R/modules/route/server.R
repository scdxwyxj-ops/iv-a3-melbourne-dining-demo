route_server <- function(id, data, state) {
  moduleServer(
    id,
    function(input, output, session) {
      choices <- landmark_choices(data)
      defaults <- unname(choices[unlist(app_settings()$route$default_stops)])
      stop_ids <- reactiveVal(defaults[!is.na(defaults)])
      edit_note <- reactiveVal("")
      model_status <- reactive({
        tryCatch(
          list(
            model = core_route_model(data, stop_ids()),
            message = NULL
          ),
          route_input_error = function(condition) {
            list(model = NULL, message = conditionMessage(condition))
          }
        )
      })
      model <- reactive(model_status()$model)
      radius <- reactive({
        value <- input$radius
        if (
          is.null(value) ||
            length(value) != 1 ||
            !is.finite(value) ||
            value < app_settings()$route$radius_min_m ||
            value > app_settings()$route$radius_max_m
        ) {
          app_settings()$route$radius_default_m
        } else {
          value
        }
      })
      target <- reactive({
        value <- input$target
        if (
          is.null(value) ||
            length(value) != 1 ||
            !is.finite(value) ||
            value < 0 ||
            value > 100
        ) {
          app_settings()$route$target_default
        } else {
          value / 100
        }
      })
      mode <- reactive({
        value <- input$mode
        if (
          is.null(value) ||
            !value %in% c("balanced", "least_detour", "meal_position")
        ) {
          "balanced"
        } else {
          value
        }
      })
      category <- reactive({
        value <- input$category
        if (
          is.null(value) ||
            !value %in% c("all", "4511", "4512")
        ) {
          "all"
        } else {
          value
        }
      })
      candidates <- reactive({
        if (is.null(model())) {
          return(core_empty_route_results(data))
        }
        core_route_recommendations(
          data,
          model(),
          radius(),
          target(),
          mode(),
          category()
        )
      })
      selected <- reactive({
        venues <- candidates()
        venues[venues$venue_id %in% state$selected_venue_id, , drop = FALSE]
      })
      observeEvent(
        input$show_map,
        {
          updateTabsetPanel(session, "view", selected = "map")
        }
      )
      observeEvent(
        input$show_recommendations,
        {
          updateTabsetPanel(session, "view", selected = "recommendations")
        }
      )
      output$selection_context <- renderUI({
        venues <- selected()
        if (nrow(venues) != 1L) {
          return(NULL)
        }
        div(
          class = "route-active-selection",
          div(
            span("Selected restaurant"),
            strong(venues$name)
          ),
          div(
            class = "route-selection-links",
            actionButton(
              session$ns("show_map"),
              "View on route",
              class = "btn-default"
            ),
            actionButton(
              session$ns("show_recommendations"),
              "Why this choice",
              class = "btn-default"
            )
          )
        )
      })
      output$edit_note <- renderText(edit_note())
      output$stops <- renderUI({
        ids <- stop_ids()
        if (!length(ids)) {
          return(p(class = "route-help", "Add two or more stops."))
        }
        tagList(
          lapply(
            seq_along(ids),
            function(i) {
              node <- get_landmark(data, ids[i])
              div(
                class = "route-stop",
                span(class = "route-stop-number", i),
                strong(node$name),
                div(
                  class = "route-stop-actions",
                  tags$button(
                    type = "button",
                    `data-route-edit` = "up",
                    `data-index` = i,
                    disabled = if (i == 1L) {
                      "disabled"
                    } else {
                      NULL
                    },
                    `aria-label` = paste("Move up", node$name),
                    "↑"
                  ),
                  tags$button(
                    type = "button",
                    `data-route-edit` = "down",
                    `data-index` = i,
                    disabled = if (i == length(ids)) {
                      "disabled"
                    } else {
                      NULL
                    },
                    `aria-label` = paste("Move down", node$name),
                    "↓"
                  ),
                  tags$button(
                    type = "button",
                    `data-route-edit` = "remove",
                    `data-index` = i,
                    `aria-label` = paste("Remove", node$name),
                    "×"
                  )
                )
              )
            }
          )
        )
      })
      observeEvent(
        input$add_stop,
        {
          id <- input$new_stop
          req(
            length(id) == 1L,
            id %in% core_landmarks(data)$poi_id
          )
          ids <- stop_ids()
          if (length(ids) >= ROUTE_MAX_STOPS) {
            edit_note("Maximum eight stops; remove one to add another.")
            return()
          }
          if (
            length(ids) &&
              identical(
                tail(ids, 1),
                id
              )
          ) {
            edit_note("This is already the last stop.")
            return()
          }
          stop_ids(c(ids, id))
          edit_note("")
          updateSelectizeInput(session, "new_stop", selected = "")
        }
      )
      observeEvent(
        input$edit_stop,
        {
          edit <- input$edit_stop
          i <- suppressWarnings(as.integer(edit$index))
          ids <- stop_ids()
          req(
            length(i) == 1L,
            !is.na(i),
            i >= 1L,
            i <= length(ids),
            edit$action %in% c("up", "down", "remove")
          )
          if (edit$action == "remove") {
            ids <- ids[-i]
          }
          if (edit$action == "up" && i > 1L) {
            ids[c(i - 1L, i)] <- ids[c(i, i - 1L)]
          }
          if (edit$action == "down" && i < length(ids)) {
            ids[c(i, i + 1L)] <- ids[c(i + 1L, i)]
          }
          stop_ids(ids)
          edit_note("")
        }
      )
      choose <- function(id) {
        req(
          length(id) == 1L,
          id %in% candidates()$venue_id
        )
        state$selected_venue_id <- id
      }
      observeEvent(input$select_venue, choose(input$select_venue))
      observeEvent(input$map_marker_click, choose(input$map_marker_click$id))
      observeEvent(
        input$full_details,
        {
          venue <- selected()
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
                  "Suggested on leg",
                  venue$leg,
                  "·",
                  round(venue$detour_m),
                  "m extra straight-line distance"
                )
              ),
              footer = modalButton("Back to itinerary")
            )
          )
        }
      )
      map_scene <- reactive({
        route <- model()
        if (is.null(route)) {
          return(list(scope = "empty-itinerary", markers = list()))
        }
        core_route_scene(route, candidates(), radius(), state$selected_venue_id)
      })
      observe({
        req(isTRUE(input$map_ready))
        core_map_render(session, "map", map_scene())
      })
      observeEvent(
        input$fit,
        {
          req(!is.null(model()))
          core_map_fit(session, "map", map_scene()$bounds)
        }
      )
      output$route_note <- renderUI({
        route <- model()
        if (is.null(route)) {
          return(p(class = "route-help", model_status()$message))
        }
        p(
          class = "route-context",
          strong(
            paste(
              nrow(route$nodes),
              "ordered stops"
            )
          ),
          span(
            paste(
              " ·",
              format(
                round(route$total_m / 1000, 2),
                nsmall = 2
              ),
              "km straight-line route ·",
              radius(),
              "m corridor"
            )
          )
        )
      })
      output$summary <- renderUI({
        venues <- candidates()
        route <- model()
        linked <- sum(
          vapply(
            venues$venue_id,
            function(id) !is.null(core_venue_details(data, id)$source),
            logical(1)
          )
        )
        div(
          class = "route-summary",
          metric_card(
            nrow(venues),
            "venues in the corridor"
          ),
          metric_card(
            if (is.null(route)) {
              "—"
            } else {
              paste0(
                format(
                  round(route$total_m / 1000, 2),
                  nsmall = 2
                ),
                " km"
              )
            },
            "straight-line itinerary"
          ),
          metric_card(
            linked,
            "linked public records",
            paste(
              nrow(venues) -
                linked,
              "retain unknown public details"
            )
          )
        )
      })
      output$formula <- renderUI({
        weights <- core_route_weights(mode())
        tagList(
          p(
            paste0(
              "Score = ",
              round(100 * weights[1]),
              "% detour fit + ",
              round(100 * weights[2]),
              "% meal-position fit."
            )
          ),
          p("Detour fit = max(0, 1 − extra distance / (2 × corridor radius))."),
          p(
            paste0(
              "Position fit is highest near ",
              round(100 * target()),
              "% of this itinerary."
            )
          ),
          p(
            "For each venue, use its smallest-extra-distance eligible leg. Equal detours use the leg closest to the preferred meal position."
          )
        )
      })
      output$ranked <- renderUI({
        route_ranked_ui(candidates(), state$selected_venue_id)
      })
      output$selection <- renderUI({
        route_selection_ui(selected(), session$ns)
      })
      output$mix <- renderUI({
        route_mix_ui(candidates())
      })
      output$distribution <- renderUI({
        route_distribution_ui(candidates(), model(), state$selected_venue_id)
      })
      output$export <- downloadHandler(
        filename = function() "route-dining-suggestions.csv",
        content = function(file) {
          venues <- candidates()
          fields <- c(
            "recommend_rank",
            "venue_id",
            "name",
            "address",
            "category",
            "leg",
            "offset_m",
            "detour_m",
            "progress",
            "fit_score"
          )
          write.csv(
            venues[, fields, drop = FALSE],
            file,
            row.names = FALSE,
            na = ""
          )
        }
      )
    }
  )
}
