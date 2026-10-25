# Cuisine/type enrichment (Compare only)

The unchanged City of Melbourne 2024 venue snapshot remains the source of locations, distances and counts. `venue-cuisines.json` is an optional-purpose enrichment used by Compare, not a replacement inventory. This matched derivative is provided under ODbL 1.0, with attribution to OpenStreetMap contributors and snapshot publisher CITTYJAMES / Heidi Gaddi. Retain these notices and share-alike requirements when distributing the enrichment. The original City of Melbourne files retain their existing CC BY 4.0 attribution.

## Source

- Dataset: https://huggingface.co/datasets/CITTYJAMES/melbourne-cafes-restaurants-osm
- File: `melbourne_cafes_restaurants_clean.csv`, 1,896 rows.
- Collection date reported by publisher: 22 October 2025. Retrieved: 23 October 2026.
- Licence: https://opendatacommons.org/licenses/odbl/1-0/
- Attribution: https://www.openstreetmap.org/copyright
- Tag definitions: https://wiki.openstreetmap.org/wiki/Key:cuisine

Direct Overpass access was attempted but failed (HTTP 406 / timeout); the documented public snapshot is used instead. Publisher extent descriptions are not fully consistent, so no completeness is assumed. This is community-tagged data, not independently verified menus or present-day opening status. No AI-predicted labels or publisher text embeddings are used.

## Matching and coverage

Normalise names by ASCII transliteration, lowercase and removing punctuation/spacing. Accept only exact normalised-name matches within 100 metres, with exactly one candidate in each direction. Do not join on nearest location alone, guess from restaurant names, or assign all branches a chain-wide cuisine. Addresses from both sources are retained for audit; they are not an exact-address validation. Possible errors from relocations, shared premises or changes between 2024 and 2025 remain. Ambiguous matches are omitted.

380 venue identities match; 305 have at least one usable cuisine/type label. The remaining 1,689 of 1,994 venues are Unclassified (including 75 matched identities without usable labels). This is only 15.3% classification coverage. Filters describe tagged results, not total availability of a cuisine. A zero filtered count means no matching tagged records, not evidence of no such restaurants.

Labels (overlap is allowed): Japanese 22, Korean 14, Thai 8, Chinese 26, Italian 23, Cafe 139, Other recorded types 121. Counts do not sum to 305 because venues may have multiple labels.

Only exact `japanese`, `korean`, `thai`, `chinese`, `italian` source tags become those labels. Cafe comes from `amenity=cafe`; it is a venue type. Other nonempty tags (including dish tags such as sushi or pizza) are retained as Other recorded types, not inferred national cuisines. Coffee tags alone on a non-cafe do not imply Cafe. All raw cuisine values and source object URLs are retained.

## UI behaviour

Multiple choices use OR (Japanese or Korean), with each stable venue ID counted once. All dining / clearing the selection shows every venue, including Unclassified. Venue format and radius remain independent filters. Map colours identify cuisine/type; A/B circle colours identify catchments. A point with multiple active types uses the labelled Multiple selected types colour and its popup lists all recorded labels. The existing chart continues to compare venue formats, within the selected cuisine scope.

## Reproduce

Download the canonical CSV from the source link, then run from the repository root:

`Rscript scripts/match-cuisines.R path/to/melbourne_cafes_restaurants_clean.csv data/venue-cuisines.json`

Use a UTF-8 R locale. `tests/cuisine_checks.R` checks unchanged base counts, matching coverage, OR filtering, duplicate prevention, reset and reactive output. The JSON includes original and matched names, addresses, distances, raw tags, source IDs, URLs, matching method and dates. Original venue and landmark files are not modified.
