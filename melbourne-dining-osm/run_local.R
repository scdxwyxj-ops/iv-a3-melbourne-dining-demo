# In RStudio: open this file and click Source, or use Run App on app.R.
# Resolve this file's folder when sourced, so the current working directory
# does not have to be the application folder.
local({
  source_file <- NULL
  for (frame in sys.frames()) {
    if (!is.null(frame$ofile)) source_file <- frame$ofile
  }
  app_dir <- if (is.null(source_file)) getwd() else dirname(normalizePath(source_file, mustWork = TRUE))
  if (!file.exists(file.path(app_dir, "app.R"))) stop("Open run_local.R in the app folder and click Source.")
  if (dir.exists(file.path(app_dir, ".Rlibrary"))) .libPaths(c(file.path(app_dir, ".Rlibrary"), .libPaths()))
  if (!requireNamespace("shiny", quietly = TRUE)) stop("Install shiny first; see README.md.")
  shiny::runApp(app_dir, host = "127.0.0.1", port = 7463L, launch.browser = TRUE)
})
