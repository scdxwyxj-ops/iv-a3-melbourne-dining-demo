# GEOM90007 Week 8.5 helper, retained unmodified with its licence.
source('R/vendor/tableau-in-shiny-v1.2.R')
# Keep the existing entry point for compatibility with the group's UI.
tableau_placeholder <- function() {
  div(class='overview-tableau',
    tableauPublicViz(id='overview-tableau',
      url='https://public.tableau.com/views/Overview_diningvenues/OverviewCharts',
      height='800px', style='width:100%;', toolbar='hidden', 'hide-tabs'=TRUE),
    tags$script(type='module', src='js/overview-tableau.js'),
    p(id='overview-sync-status', class='help-copy', role='status', 'Loading linked charts…'))
}

tableau_area_server <- function(input, session, state, areas=character()) {
  observeEvent(input$overview_chart_area, {
    area <- input$overview_chart_area
    req(is.character(area), length(area) == 1L)
    aliases <- c('West Melbourne (Ind.)'='West Melbourne (Industrial)',
                 'West Melbourne (Res.)'='West Melbourne (Residential)')
    if (area %in% names(aliases)) area <- unname(aliases[[area]])
    req(area %in% areas)
    state$area <- area
  })
  observe({
    req(isTRUE(input$overview_tableau_ready))
    session$sendCustomMessage('overview-area', list(area=state$area))
  })
}
