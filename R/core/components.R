# Shared presentation vocabulary. Feature modules should reuse these components.
feature_heading <- function(title, subtitle, owner = "Owner to be assigned") {
  div(
    class = "feature-heading",
    div(
      h1(title),
      p(subtitle)
    ),
    div(
      class = "feature-meta",
      span(class = "status-pill", "Feature placeholder"),
      span(class = "owner-label", owner)
    )
  )
}

panel_card <- function(title, ..., class = "") {
  div(
    class = paste("panel-card", class),
    h2(class = "panel-title", title),
    ...
  )
}

placeholder_canvas <- function(title, description, kind = "map") {
  div(
    class = paste("placeholder-canvas", paste0("placeholder-", kind)),
    span(class = "placeholder-symbol", "◇", `aria-hidden` = "true"),
    h3(title),
    p(description),
    span(class = "placeholder-label", "Reserved for implementation")
  )
}

metric_card <- function(value, label, note = NULL, tone = "primary") {
  div(
    class = paste("metric-card", paste0("tone-", tone)),
    strong(class = "metric-value", value),
    span(class = "metric-label", label),
    if (!is.null(note)) {
      p(class = "metric-note", note)
    }
  )
}

category_legend <- function() {
  div(
    class = "category-legend",
    span(
      span(class = "legend-dot cafe"),
      "Cafés & restaurants"
    ),
    span(
      span(class = "legend-dot takeaway"),
      "Takeaway"
    )
  )
}

next_step_note <- function(...) div(class = "next-step-note", ...)
