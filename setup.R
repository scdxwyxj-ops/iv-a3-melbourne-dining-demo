# Prepare the R environment and launch the application.
arguments <- commandArgs(trailingOnly = TRUE)
script_path <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script_path) == 1L) {
  setwd(dirname(normalizePath(sub("^--file=", "", script_path))))
}

user_library <- strsplit(
  Sys.getenv("R_LIBS_USER"),
  .Platform$path.sep,
  fixed = TRUE
)[[1L]][1L]
user_library <- path.expand(user_library)
dir.create(user_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(user_library, .libPaths()))

packages <- c("shiny", "jsonlite", "shinyjs")
missing_packages <- packages[
  !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  install.packages(
    missing_packages,
    repos = "https://cloud.r-project.org",
    lib = user_library
  )
}
ready <- vapply(packages, requireNamespace, logical(1), quietly = TRUE)
if (!all(ready)) {
  stop(
    "Complete the installation of: ",
    paste(packages[!ready], collapse = ", ")
  )
}
cat("R environment ready.\n")

if (!"--check" %in% arguments) {
  config <- jsonlite::fromJSON("config.json", simplifyVector = FALSE)
  shiny::runApp(
    ".",
    host = config$app$host,
    port = config$app$port,
    launch.browser = FALSE
  )
}
