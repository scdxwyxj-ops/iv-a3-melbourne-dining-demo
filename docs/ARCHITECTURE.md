# Shiny module structure and interfaces

The application has four feature modules that share a data snapshot and styles. Each feature directory contains `ui.R` and `server.R`. Shared interfaces live in `R/core/`; module ownership is recorded in the [responsibility table](TEAM_ASSIGNMENTS.md).

## Application entry point

`app.R` loads the shared core and feature modules, reads the data, and assembles the navigation. `server()` creates a separate state object for each user session and passes `data` and `state` to each module. The read-only data snapshot can be shared across sessions.

All modules use the same argument pattern:

```r
nearby_ui(id, data)
nearby_server(id, data, state)
```

Input and output IDs in the UI are namespaced with `NS(id)`. Servers use `moduleServer(id, ...)`. `app.R` manages the application entry point. Modules exchange IDs through shared state without relying on another module's internal input IDs.

## Shared core

| File | Interfaces and purpose |
|---|---|
| `R/core/data.R` | `load_app_data()`, `landmark_choices()`, and `get_landmark()` for shared data loading and validation |
| `R/core/geo.R` | `haversine_m()` and `venues_near()` for consistent straight-line distance and catchment calculations |
| `R/core/state.R` | `create_shared_state()` for separate state in each session |
| `R/core/components.R` | Page headings, cards, metrics, and placeholder regions |
| `R/core/tableau.R` | `tableau_placeholder()` and the Tableau integration location |

`data$venues` is a data.frame with one venue per row. `data$landmarks` contains place-of-interest records, `data$boundaries` contains the GeoJSON list, and `data$areas` supplies area names. See the [data documentation](../data/README.md) for field definitions.

## Shared state

| Field | Initial value | Main writing module |
|---|---|---|
| `area` | Carlton | Area overview |
| `landmark_id` | Federation Square's `poi_id` | Nearby dining |
| `radius_m` | 600 | Nearby dining |
| `comparison_a_id` | Federation Square's `poi_id` | Landmark comparison |
| `comparison_b_id` | State Library Victoria's `poi_id` | Landmark comparison |
| `comparison_radius_m` | 600 | Landmark comparison |
| `selected_venue_id` | NULL | Nearby dining selects a venue; the details module may change it |
| `saved_venue_ids` | Empty character vector | Venue details and shortlist |

The comparison module keeps its own landmark and radius settings to avoid changing the nearby dining settings. Venue references use `venue_id`, and place-of-interest references use `poi_id`. Names and coordinates are not join keys.

`create_shared_state()` is called inside `server()`. State is read and written within Shiny reactive contexts, so selections and shortlists remain separate across sessions. Cross-session persistence is not implemented.

## Connecting nearby dining to venue details

The `nearby_venues()` reactive in `R/modules/nearby/server.R` returns venues within the radius, including `distance_m`, ordered by distance. The map and list will read this object. Venue selection should write `state$selected_venue_id`, which the details module uses to retrieve the record.

The shortlist module manages `state$saved_venue_ids`. Save, remove, and export actions use venue IDs. Missing seating values are displayed as Unknown in venue details.

## Styles and dependencies

Shared styles live in `www/css/common.css`; module styles use the corresponding `www/css/{module}.css` file. Modules access shared colours through CSS tokens such as `var(--color-primary)`. Component conventions are documented in the [design language](DESIGN_LANGUAGE.md).

The current runtime dependencies are `shiny` and `jsonlite`. When adding a dependency, update the root README's installation instructions. Package installation belongs to environment setup; application scripts do not call `install.packages()`.

## Implementation status

Area overview, nearby dining, and landmark comparison counts are connected to the data. Maps, venue lists, and category charts remain placeholders. Venue details and shortlist interactions are not connected.

Leaflet may be used for maps, and a Tableau integration location is reserved. Tram data, live opening status, and walking routes are outside the current prototype's scope.
