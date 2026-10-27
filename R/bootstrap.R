# Load shared functions, chart builders and page modules in dependency order.
load_app_code <- function(envir = parent.frame()) {
  core_files <- c(
    "settings",
    "data",
    "geo",
    "state",
    "components",
    "maps",
    "google",
    "details",
    "route",
    "tableau"
  )
  module_files <- list(
    area = c("ui", "server"),
    nearby = c("charts", "ui", "server"),
    compare = c("ui", "server"),
    route = c("presenters", "ui", "server")
  )
  for (name in core_files) {
    sys.source(
      file.path("R", "core", paste0(name, ".R")),
      envir = envir
    )
  }
  for (feature in names(module_files)) {
    for (part in module_files[[feature]]) {
      sys.source(
        file.path("R", "modules", feature, paste0(part, ".R")),
        envir = envir
      )
    }
  }
}
