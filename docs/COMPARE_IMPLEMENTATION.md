# Compare places

## Update: 25 October 2026

Compare now uses standard OpenStreetMap raster tiles at https://tile.openstreetmap.org/{z}/{x}/{y}.png with visible contributor attribution, normal browser caching and no prefetch/offline download. The MapLibre/OpenFreeMap dependencies are no longer loaded by Compare; archived assets remain untouched. Follow https://operations.osmfoundation.org/policies/tiles/ when deploying.

The shared comparison radius is a 200–1,200 metre slider with 1-metre steps (default 600). Both landmark selectors expose all 242 repository records, including non-tourism facilities; duplicate names are disambiguated by record ID. Places without an existing licensed photograph show Photo unavailable.

All 1,994 dining records are searched before radius/format filtering; no city-centre subset is applied. Local venues.csv and landmarks.csv match the GitHub default-branch blobs checked on 25 October. This snapshot covers the City of Melbourne council area / 13 CLUE areas, NOT Greater Melbourne. The UI states this limitation. No new dataset is claimed or fabricated. Changes are limited to Compare; the shared starter helper and other members' modules are unchanged. Regression test: tests/osm_radius_checks.R.

## Current interaction (cuisine experiment retired)

At the user's request, cuisine filters/enrichment are no longer used by Compare. Original All dining / venue-format filtering and A-only/B-only/shared point colours are restored. Research data and preparation scripts are retained, not deleted. Earlier cuisine notes describe the retired experiment.

Click a venue dot to show a fixed top-right card with source name, address, venue format, actual straight-line distances to both landmarks and catchment membership. An orange cutlery pin highlights the selection without a location-anchored popup. Collapse retains the selected pin; close clears it. Selecting another venue expands and updates the card. Radius/origin/format changes clear the local card. The shared selected venue remains available to Details unless explicitly closed. Mobile cards sit below the map toolbar. No invented review, menu, price or opening-hour content is added. Regression checks: `tests/card_checks.R`; `tests/cuisine_checks.R` now only validates retained research IDs.

Implemented for mngj506 with OpenAI Codex assistance on 23 October 2026.

From the repository root, run `shiny::runApp()` and choose **3 · Compare places**. Required packages: shiny, jsonlite and leaflet. Install separately with `install.packages(c("shiny", "jsonlite", "leaflet"))`. The original starter README and notice describe the earlier scaffold; this document records the Compare implementation.

All counts, bars, map points and lists use one radius, venue-format and multi-select cuisine/type filter. Shared venues count in each catchment; the union counts them once. Point colours identify cuisine/type; teal and purple dashed circles identify A and B. Bars use a common count scale with explicit A/B labels. The original census has no cuisine or price fields. Compare now uses a separate, partially matched OSM enrichment; see `data/CUISINE_DATA.md` for provenance, dates, coverage, licence and limitations. The original datasets are unchanged.

Map clicks and the selector write `state$selected_venue_id`. Compare does not modify Nearby settings or saved IDs. Details display and saving depend on the separate unfinished details module. Identical landmarks and empty results have explicit messages. Lists retain separate venue IDs at shared coordinates. The table shows at most 100 rows; the searchable selector includes all results. Basemap tiles require internet; data and calculations are local.

Files: `R/modules/compare/ui.R`, `R/modules/compare/server.R`, `www/css/compare.css`. No Tableau workbook is provided. AI assistance covered code, styling, tests and these notes; review and acknowledge in the assignment report as required.

References: https://rstudio.github.io/leaflet/reference/map-layers.html and https://shiny.posit.co/r/reference/shiny/latest/testserver.html .

Run regression checks from the repository root: `Rscript tests/compare_checks.R`.

## Travel-planner redesign

The desktop layout uses an independently scrolling comparison sidebar and a full-height map. On narrow screens the map appears above the controls. The venue list opens in a modal. Landmark cards use real Wikimedia Commons photographs: clickable credits and original licence links are recorded in `www/compare-assets/credits.json`. Counts and charts are computed from actual data, not the generated design preview. Both catchments have dashed outlines; selected landmark names remain visible on the map.

The basemap uses OpenFreeMap vector tiles through locally bundled MapLibre GL 4.7.1 and its Leaflet adapter 0.0.22. The local Positron-derived style softens buildings, hides route shields, and adds pale blue water and green parks. Map tiles/fonts require an internet connection and WebGL; photographs and scripts are local. All catchment shapes and venue markers use SVG rendering. CARTO Positron was rejected during browser QA because the service returned API-key-required tiles. No paid key is required by the final implementation. Keep the map's attribution visible. Vendor licences accompany the bundled scripts. Photo files are unmodified and displayed with CSS crops; retain their author/licence credits when sharing.

Browser checks covered desktop and 390-pixel mobile layouts, radius changes, the shared-venue modal, absence of horizontal overflow and JavaScript errors. Regression tests check the 303/619/65 reference counts, category scope, empty results, identical landmarks and selection state.
