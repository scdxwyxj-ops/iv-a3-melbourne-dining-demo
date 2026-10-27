# Shared runtime settings, loaded once for each R process.
app_settings <- local({
  settings <- NULL
  function() {
    if (is.null(settings)) {
      settings <<- jsonlite::fromJSON("config.json", simplifyVector = FALSE)
    }
    settings
  }
})

# Browser bootstrap carries the map style and SDK timing settings.
public_browser_settings <- function() {
  config <- app_settings()
  list(
    map = config$map,
    google = list(
      sdk_timeout_ms = config$google$sdk_timeout_ms,
      query_timeout_ms = config$google$query_timeout_ms
    )
  )
}
