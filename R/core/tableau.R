# GEOM90007 Week 8.5 helper, retained unmodified with its licence.
source("R/vendor/tableau-in-shiny-v1.2.R", local = TRUE)
# Keep the existing entry point for compatibility with the group's UI.
tableau_overview_ui <- function() {
  div(
    class = "overview-tableau",
    # The dedicated adapter below handles events; avoid duplicate vendor telemetry
    # (Tableau action filters can reject getFilterAsync in the generic helper).
    tableauPublicViz(
      id = "overview-tableau",
      url = core_tableau_overview_url(),
      height = "800px",
      style = "width:100%;",
      toolbar = "hidden",
      "hide-tabs" = TRUE
    )[[1L]],
    tags$script(type = "module", src = "js/overview-tableau.js?v=4.6"),
    p(
      id = "overview-sync-status",
      class = "help-copy",
      role = "status",
      "Loading linked charts…"
    )
  )
}

tableau_area_server <- function(input, session, state, areas = character()) {
  observeEvent(input$overview_chart_area, {
    area <- input$overview_chart_area
    req(is.character(area), length(area) == 1L)
    aliases <- stats::setNames(
      names(core_tableau_area_aliases()),
      unname(core_tableau_area_aliases())
    )
    if (area %in% names(aliases)) {
      area <- unname(aliases[[area]])
    }
    req(area %in% areas)
    state$area <- area
  })
  observe({
    req(isTRUE(input$overview_tableau_ready))
    session$sendCustomMessage("overview-area", list(area = state$area))
  })
}
