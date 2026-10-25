# R owns validated landmark/search parameters; restaurant data stays in UI Kit.
create_osm_server <- function(config, landmarks) {
  force(config)
  force(landmarks)

  function(input, output, session) {
    calls <- shiny::reactiveVal(0L)
    last_call <- shiny::reactiveVal(NULL)

    # Validated search state shared with the browser.
    selected_landmark <- shiny::reactive({
      i <- match(input$landmark %||% "", landmarks$landmark_id)
      if (is.na(i)) NULL else landmarks[i, , drop = FALSE]
    })

    scene <- shiny::reactive({
      lm <- selected_landmark()
      radius <- suppressWarnings(as.numeric(input$radius %||% "600"))
      if (length(radius) != 1L || !is.finite(radius) ||
          radius < 200 || radius > 1200 || radius %% 50 != 0)
        radius <- 600
      cuisine <- input$cuisine %||% ""
      if (length(cuisine) != 1L || !cuisine %in% c("", unname(cuisine_types))) cuisine <- ""
      list(
        landmark = if (is.null(lm)) NULL else as.list(lm),
        radius = radius,
        cuisine = cuisine,
        rankPreference = "DISTANCE",
        key = paste(if (is.null(lm)) "" else lm$landmark_id, radius, cuisine, sep = "|")
      )
    })

    # Browser initialization and landmark selection.
    shiny::observeEvent(input$client_ready, {
      session$sendCustomMessage("osm-init", list(
        browserKey = config$browser_key,
        requestLimit = config$request_limit,
        landmarks = lapply(seq_len(nrow(landmarks)), function(i)
          as.list(landmarks[i, c("landmark_id", "landmark_name", "latitude", "longitude")]))
      ))
      session$sendCustomMessage("osm-scene", scene())
    })

    shiny::observeEvent(input$map_landmark, {
      if (is.character(input$map_landmark) && length(input$map_landmark) == 1L &&
          input$map_landmark %in% landmarks$landmark_id)
        shiny::updateSelectizeInput(session, "landmark", selected = input$map_landmark)
    })

    shiny::observe({
      shiny::req(input$client_ready)
      session$sendCustomMessage("osm-scene", scene())
    })

    # Explicit searches only, with readiness, quota and cooldown checks.
    notice <- function(text) session$sendCustomMessage("osm-notice", list(text = text))
    shiny::observeEvent(input$search,
      {
        query <- scene()
        if (is.null(query$landmark)) {
          notice("Choose a landmark first.")
          return()
        }
        if (!nzchar(config$browser_key) || !identical(input$places_status, "ready")) {
          notice("Restaurant search is not ready. Check the browser key, enabled APIs and website restrictions.")
          return()
        }
        if (calls() >= config$request_limit) {
          notice("This session's search limit has been reached.")
          return()
        }
        if (!is.null(last_call()) && as.numeric(difftime(Sys.time(), last_call(), units = "secs")) < 3) {
          notice("Please wait a moment before searching again.")
          return()
        }
        last_call(Sys.time())
        calls(calls() + 1L)
        query$requestId <- calls()
        session$sendCustomMessage("osm-search", query)
      },
      ignoreInit = TRUE
    )

    # Context labels and connection status.
    output$active_context <- shiny::renderUI({
      query <- scene()
      shiny::tagList(
        shiny::h2(if (is.null(query$landmark)) "Start with a landmark" else query$landmark$landmark_name),
        shiny::div(
          class = "context-chips", shiny::span(paste(query$radius, "m radius")),
          shiny::span(if (nzchar(query$cuisine)) cuisine_label(query$cuisine) else "All cuisines"),
          shiny::span("Nearest distance")
        )
      )
    })

    output$connection_status <- shiny::renderText(paste(
      "OpenStreetMap with Google Places UI Kit · Restaurant search:",
      input$places_status %||% "loading", "· Searches this session:", calls(), "/", config$request_limit
    ))
  }
}
