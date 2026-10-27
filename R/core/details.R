core_venue_details <- function(data, venue_id) {
  record <- data$details$records[[venue_id]]
  if (is.null(record)) {
    list(venue_id = venue_id, match_status = "unmatched")
  } else {
    record
  }
}

core_detail_text <- function(detail, field, fallback = "—") {
  value <- detail[[field]]
  if (
    is.null(value) ||
      length(value) != 1L ||
      is.na(value) ||
      !nzchar(trimws(as.character(value)))
  ) {
    fallback
  } else {
    as.character(value)
  }
}

core_tag_label <- function(value) {
  gsub(
    "_",
    " ",
    gsub(";", " · ", value, fixed = TRUE),
    fixed = TRUE
  )
}

core_venue_card <- function(venue, data) {
  detail <- core_venue_details(data, venue$venue_id)
  cuisine <- core_detail_text(detail, "cuisine", "")
  tags$button(
    type = "button",
    class = "nearby-venue venue-card",
    `data-venue-id` = venue$venue_id,
    `aria-pressed` = "false",
    span(
      class = "nearby-venue-top",
      strong(class = "nearby-venue-name", venue$name),
      span(
        class = "nearby-distance",
        paste(
          round(venue$distance_m),
          "m"
        )
      )
    ),
    span(
      class = "nearby-venue-category",
      span(
        class = paste(
          "legend-dot",
          if (venue$category_code == "4512") {
            "takeaway"
          } else {
            "cafe"
          }
        )
      ),
      venue$category
    ),
    span(class = "nearby-venue-address", venue$address),
    span(
      class = "venue-card-facts",
      if (nzchar(cuisine)) {
        span(class = "venue-tag", core_tag_label(cuisine))
      },
      span(
        class = "venue-data-tag",
        if (!is.null(detail$source)) {
          "Public record linked"
        } else {
          "Census record"
        }
      )
    )
  )
}

core_venue_detail_ui <- function(
  venue,
  data,
  context = NULL,
  config = core_google_config()
) {
  live_record <- core_google_detail_ui(venue, config)
  div(
    class = "venue-details",
    div(
      class = "venue-detail-heading",
      span(class = "venue-tag", venue$category),
      h3(venue$name),
      p(venue$address),
      if (!is.null(context)) {
        p(class = "venue-context", context)
      }
    ),
    live_record
  )
}
