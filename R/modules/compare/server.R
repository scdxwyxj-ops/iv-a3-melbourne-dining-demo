# AI-assisted Compare implementation, 2026-10-23. See COMPARE_IMPLEMENTATION.md.
compare_results <- function(data, a_id, b_id, radius, category = "all") {
  a <- venues_near(data, a_id, radius); b <- venues_near(data, b_id, radius)
  if (category != "all") { a <- a[a$category_code == category, , drop = FALSE]; b <- b[b$category_code == category, , drop = FALSE] }
  shared <- intersect(a$venue_id, b$venue_id); ids <- union(a$venue_id, b$venue_id)
  v <- data$venues[match(ids, data$venues$venue_id), , drop = FALSE]
  v$distance_a <- a$distance_m[match(ids, a$venue_id)]; v$distance_b <- b$distance_m[match(ids, b$venue_id)]
  v$membership <- ifelse(ids %in% shared, "shared", ifelse(ids %in% a$venue_id, "a", "b"))
  list(a = a, b = b, shared = shared, venues = v)
}
compare_server <- function(id, data, state) {
  moduleServer(id, function(input, output, session) {
    selected_id <- reactiveVal(NULL)
    card_collapsed <- reactiveVal(FALSE)
    observeEvent(input$landmark_a, { req(input$landmark_a %in% data$landmarks$poi_id); state$comparison_a_id <- input$landmark_a })
    observeEvent(input$landmark_b, { req(input$landmark_b %in% data$landmarks$poi_id); state$comparison_b_id <- input$landmark_b })
    observeEvent(input$radius, {
      radius <- suppressWarnings(as.numeric(input$radius))
      req(length(radius) == 1L, is.finite(radius), radius >= 200, radius <= 1200)
      state$comparison_radius_m <- radius
    })
    result <- reactive({
      category <- input$category; if (is.null(category)) category <- "all"
      req(category %in% c("all", "4511", "4512"))
      compare_results(data, state$comparison_a_id, state$comparison_b_id, state$comparison_radius_m, category)
    })
    origins <- reactive(rbind(get_landmark(data, state$comparison_a_id), get_landmark(data, state$comparison_b_id)))
    photo_credits <- jsonlite::fromJSON("www/compare-assets/credits.json", simplifyVector = FALSE)
    photo <- function(index) {
      name <- origins()$name[index]; p <- photo_credits[[name]]
      if (is.null(p)) return(span("Photo unavailable"))
      tags$a(href = p$source, target = "_blank", rel = "noopener noreferrer",
        title = paste(p$author, p$license, "· View original and licence"),
        tags$img(src = paste0("compare-assets/", p$file), alt = name),
        span(class = "compare-photo-credit", paste(p$author, "·", p$license)))
    }
    output$photo_a <- renderUI(photo(1))
    output$photo_b <- renderUI(photo(2))
    output$notice <- renderUI({
      if (state$comparison_a_id == state$comparison_b_id) p(class = "compare-notice", "Same landmark selected twice: both counts match and every result is shared.")
      else if (!nrow(result()$venues)) p(class = "compare-notice", "No matching venues. Try All dining or a larger radius.")
    })
    output$counts <- renderUI({
      r <- result(); o <- origins()
      tagList(div(class = "compare-totals",
        div(class = "compare-total", strong(nrow(r$a)), span("Near A")),
        div(class = "compare-total b", strong(nrow(r$b)), span("Near B"))),
        div(class = "compare-overlap", div(class = "compare-venn", `aria-hidden` = "true", tags$i(), tags$i()),
          div(strong(paste(length(r$shared), "venues in both areas")),
            p(paste("Within", state$comparison_radius_m, "m of both landmarks.")))))
    })
    output$insight <- renderUI({
      r <- result(); delta <- nrow(r$b) - nrow(r$a); o <- origins()
      message <- if (delta == 0) "Both places have the same number of matching venues."
        else paste(abs(delta), "more venues near", paste0(o$name[if (delta > 0) 2 else 1], "."))
      div(class = "compare-insight", icon("chart-simple"), " ", message)
    })
    output$map_scope <- renderUI(span(class = "compare-scope", paste(state$comparison_radius_m, "m radius")))
    output$map <- leaflet::renderLeaflet({
      r <- result(); o <- origins(); radius <- state$comparison_radius_m
      cols <- c(a = "#087f80", b = "#7961b0", shared = "#203b36")
      m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = FALSE, zoomControl = FALSE))
      m <- leaflet::addAwesomeMarkers(m, lng = numeric(0), lat = numeric(0), group = "selected-venue")
      m <- leaflet::addTiles(m, urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        options = leaflet::tileOptions(maxZoom = 19))
      m <- htmlwidgets::onRender(m, "function(el,x){
        var map=this;
        L.control.zoom({position:'bottomright'}).addTo(map);
        var bounds=map.getBounds();map.on('resize',function(){map.fitBounds(bounds,{animate:false});});
      }")
      m <- leaflet::addCircles(m, lng = o$longitude, lat = o$latitude, radius = radius, color = c(cols[["a"]], cols[["b"]]),
        weight = 2.5, opacity = 1, fillOpacity = .055, dashArray = "8 7", label = paste(c("A:", "B:"), o$name))
      v <- r$venues
      if (nrow(v)) {
        m <- leaflet::addCircleMarkers(m, lng = v$longitude, lat = v$latitude, layerId = v$venue_id, radius = 3.5,
          color = "#ffffff", weight = .7, fillColor = unname(cols[v$membership]), fillOpacity = .85, label = v$name)
      }
      m <- leaflet::addCircleMarkers(m, lng = o$longitude, lat = o$latitude, radius = 17,
        color = "white", weight = 3, fillColor = c(cols[["a"]], cols[["b"]]), fillOpacity = 1,
        label = o$name)
      m <- leaflet::addLabelOnlyMarkers(m, lng = o$longitude, lat = o$latitude, label = c("A", "B"),
        labelOptions = leaflet::labelOptions(noHide = TRUE, direction = "center", textOnly = TRUE,
          style = list("color" = "white", "font-weight" = "bold", "font-size" = "15px")))
      m <- leaflet::addScaleBar(m, position = "bottomright", options = leaflet::scaleBarOptions(imperial = FALSE))
      m <- leaflet::addLabelOnlyMarkers(m, lng = o$longitude, lat = o$latitude, label = o$name,
        labelOptions = leaflet::labelOptions(noHide = TRUE, direction = "right", offset = c(23, 0),
          className = "compare-landmark-name", style = list("font-weight" = "700", "font-size" = "12px")))
      lat_pad <- radius / 111000 * 1.25; lon_pad <- lat_pad / cos(mean(o$latitude) * pi / 180)
      leaflet::fitBounds(m, min(o$longitude) - lon_pad, min(o$latitude) - lat_pad, max(o$longitude) + lon_pad, max(o$latitude) + lat_pad)
    })
    observeEvent(input$recenter, {
      o <- origins(); lat_pad <- state$comparison_radius_m / 111000 * 1.25
      lon_pad <- lat_pad / cos(mean(o$latitude) * pi / 180)
      leaflet::fitBounds(leaflet::leafletProxy("map", session), min(o$longitude) - lon_pad, min(o$latitude) - lat_pad,
        max(o$longitude) + lon_pad, max(o$latitude) + lat_pad)
    })
    observeEvent(input$explore, {
      showModal(modalDialog(title = "Explore venues", size = "l", easyClose = TRUE,
        selectInput(session$ns("scope"), "Show venues", c("In both catchments" = "shared", "Only near A" = "a", "Only near B" = "b", "Either catchment" = "all"), selected = "shared"),
        uiOutput(session$ns("list_note")), div(class = "compare-table", tableOutput(session$ns("venues"))),
        selectizeInput(session$ns("venue"), "Select a venue", choices = NULL),
        actionButton(session$ns("select_venue"), "Use selected venue", class = "btn-primary"),
        p(class = "help-copy", "Selection is passed to Details & shortlist; that module is still under development."),
        footer = modalButton("Back to map")))
    })
    output$chart <- renderUI({
      r <- result(); codes <- c("4511", "4512"); labels <- c("Cafes & restaurants", "Takeaway")
      a <- vapply(codes, function(x) sum(r$a$category_code == x), integer(1)); b <- vapply(codes, function(x) sum(r$b$category_code == x), integer(1))
      scale <- max(1, a, b)
      tagList(lapply(seq_along(codes), function(i) div(class = "compare-chart-group", h3(labels[i]),
        lapply(seq_len(2), function(j) {
          value <- if (j == 1) a[i] else b[i]
          div(class = "compare-bar-row", span(c("A", "B")[j]), div(class = "compare-bar-track",
            div(class = paste("compare-bar", c("bar-a", "bar-b")[j]), style = paste0("width:", 100 * value / scale, "%;"))), strong(value))
        }))), p(class = "help-copy", paste("Shared scale: 0 to", scale, "venues.")))
    })
    listed <- reactive({
      v <- result()$venues; scope <- input$scope; if (is.null(scope)) scope <- "shared"
      if (scope != "all") v <- v[v$membership == scope, , drop = FALSE]
      v[order(v$name, v$venue_id), , drop = FALSE]
    })
    output$list_note <- renderUI({
      n <- nrow(listed())
      p(class = "help-copy", if (!n) "No venues in this group. Try another group or a larger radius."
        else paste(n, "venues. Table shows the first", min(n, 100), "alphabetically; the selector includes all results. A dash means outside that catchment."))
    })
    output$venues <- renderTable({
      v <- head(listed(), 100)
      data.frame(Venue = v$name, Address = v$address, `A distance (m)` = ifelse(is.na(v$distance_a), "-", round(v$distance_a)),
        `B distance (m)` = ifelse(is.na(v$distance_b), "-", round(v$distance_b)), check.names = FALSE)
    }, striped = TRUE, spacing = "s", sanitize.text.function = htmltools::htmlEscape)
    observe({
      input$explore
      v <- listed()
      updateSelectizeInput(session, "venue", choices = stats::setNames(v$venue_id, paste(v$name, v$address, v$venue_id, sep = " · ")), selected = character(0), server = TRUE)
    })
    observeEvent(input$select_venue, {
      req(input$venue %in% listed()$venue_id); state$selected_venue_id <- input$venue
      selected_id(input$venue); card_collapsed(FALSE); removeModal()
    })
    observeEvent(input$map_marker_click, {
      selected <- input$map_marker_click$id; req(selected %in% result()$venues$venue_id); state$selected_venue_id <- selected
      selected_id(selected); card_collapsed(FALSE)
    })
    # Filter/origin changes rebuild the map. Clear local selection to prevent stale cards.
    observeEvent(result(), { selected_id(NULL); card_collapsed(FALSE) })
    observeEvent(input$card_toggle, { card_collapsed(!card_collapsed()) })
    observeEvent(input$card_close, {
      if (identical(state$selected_venue_id, selected_id())) state$selected_venue_id <- NULL
      selected_id(NULL); card_collapsed(FALSE)
    })
    selected_venue <- reactive({
      id <- selected_id(); v <- result()$venues
      if (is.null(id)) return(v[FALSE, , drop = FALSE])
      v[v$venue_id == id, , drop = FALSE]
    })
    observeEvent(selected_id(), {
      proxy <- leaflet::clearGroup(leaflet::leafletProxy("map", session), "selected-venue")
      v <- isolate(selected_venue())
      if (nrow(v)) leaflet::addAwesomeMarkers(proxy, lng = v$longitude, lat = v$latitude,
        group = "selected-venue", layerId = paste0("selected-", v$venue_id), label = v$name,
        icon = leaflet::awesomeIcons(icon = "cutlery", library = "glyphicon", markerColor = "orange", iconColor = "white"))
    }, ignoreNULL = FALSE)
    output$venue_card <- renderUI({
      v <- selected_venue(); if (!nrow(v)) return(NULL)
      o <- origins()
      distances <- haversine_m(o$longitude, o$latitude, v$longitude, v$latitude)
      div(class = paste("compare-venue-card", if (card_collapsed()) "is-collapsed" else ""),
        role = "region", `aria-label` = "Selected restaurant", `aria-live` = "polite",
        div(class = "compare-card-header", div(span(class = "compare-card-eyebrow", "SELECTED VENUE"), h3(v$name)),
          actionButton(session$ns("card_toggle"), if (card_collapsed()) "+" else "−", title = if (card_collapsed()) "Expand" else "Collapse", `aria-expanded` = if (card_collapsed()) "false" else "true"),
          actionButton(session$ns("card_close"), "×", title = "Close and deselect", `aria-label` = "Close and deselect")),
        if (!card_collapsed()) div(class = "compare-card-body", p(class = "compare-card-category", v$category),
          p(class = "compare-card-address", v$address),
          div(class = "compare-card-distances", span(paste("A ·", round(distances[1]), "m")), span(paste("B ·", round(distances[2]), "m"))),
          p(class = "compare-card-description", switch(v$membership, a = "Within A's search area only.", b = "Within B's search area only.", shared = "Within both search areas.")),
          tags$small("Straight-line distance · 2024 census record")))
    })
  })
}
