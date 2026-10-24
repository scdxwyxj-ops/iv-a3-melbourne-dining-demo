# Data snapshot

This directory contains dining, place-of-interest, and CLUE area data that the application can read directly. The snapshot was prepared on 11 October 2026; the dining census year is 2024. The preparation date is not the survey or update date of each source dataset.

## Files and loading

| File | Record unit and size | Purpose |
|---|---|---|
| `venues.csv` | 1,994 dining venues, one venue per row | Venue locations, categories, and seating attributes |
| `landmarks.csv` | 242 place-of-interest records | Landmark candidates and origin coordinates |
| `clue_areas.geojson` | 13 CLUE areas | Area boundaries and names |
| `manifest.json` | Sources, transformations, counts, and SHA-256 checksums | Snapshot description and file integrity checks |

CSV files use UTF-8 encoding and comma delimiters. The GeoJSON retains the source geometries and properties. The repository distributes a fixed, processed snapshot; raw exports and processing scripts are not included.

Run the following in an R console from the repository root:

```r
source("R/core/data.R")
data <- load_app_data("data")
nrow(data$venues)       # 1994
nrow(data$landmarks)    # 242
length(data$boundaries$features)  # 13
```

`load_app_data()` checks required fields, unique IDs, coordinates, data scope, and record counts. It also checks that venue area names match boundary names. File checksums are stored in `manifest.json` for separate integrity checks; the loader does not automatically verify SHA-256 values.

## Dining record processing

The original 2024 export contains 3,249 rows. Filtering to ANZSIC 4511 (Cafes and Restaurants) and 4512 (Takeaway Food Services) retains 2,893 seating records. The source may record indoor and outdoor seating for the same venue in separate rows.

The venue merge key consists of the census year, `property_id`, normalised trading name, and business address. Normalisation trims leading and trailing whitespace, collapses repeated whitespace, and ignores case. It is used for merging and stable ID generation; display names and addresses retain their source text.

The merged snapshot contains 1,994 venues: 1,645 cafes and restaurants, and 349 takeaway venues. Indoor and outdoor seating are stored in separate columns. An unrecorded seating type remains missing and must not be interpreted as zero seats.

Category, coordinates, and area are consistent within each merge group. The selected records contain no repeated seating types within a group or missing coordinates.

## Venue fields

| Field | Meaning and loading convention |
|---|---|
| `venue_id` | Stable character ID for joins and cross-page venue selection |
| `census_year` | Census year, currently 2024 |
| `property_id` | Source property ID, loaded as character |
| `name`, `address` | Source trading name and business address |
| `area` | CLUE area name, matching the GeoJSON `featurenam` property |
| `category_code` | Character code 4511 or 4512 |
| `category` | Category display label |
| `longitude`, `latitude` | Longitude and latitude in decimal degrees |
| `indoor_seats`, `outdoor_seats` | Recorded seat counts; missing values mean unknown |

`load_app_data()` converts year, coordinate, and seating columns to numeric values. Other columns remain character values.

## Places of interest and areas

`landmarks.csv` retains all 242 source records, adds a stable `poi_id`, and flattens the nested coordinates. Its fields are `poi_id`, `name`, `theme`, `sub_theme`, `longitude`, and `latitude`.

The dataset includes non-tourism facilities such as schools and is not a complete inventory of tourist attractions. `tourism_landmarks(data)` in `R/core/data.R` selects 102 visitor-oriented records from the current snapshot. `landmark_choices(data)` returns their names and original `poi_id` values for dropdown controls. Nearby dining and landmark comparison share this selection.

The selection includes source categories for museums and galleries, theatres, cinemas, parks and gardens, observation towers, aquariums, and bridges. A named inclusion list adds civic and cultural sites, heritage buildings, Queen Victoria Market, Melbourne Zoo, selected major sports venues, and Flinders Street Railway Station. These records have broader source classes that would otherwise also include offices, ordinary sports facilities, shops, or stations. The Richmond Football Club record is explicitly omitted from the park/garden category. The complete category and name rules are kept in `tourism_landmarks()`.

This selection changes interface choices only; all 242 source records remain in `landmarks.csv`. Names and coordinates are retained as supplied. Inclusion does not verify current names, opening status, visitor access, or tours. The original six choices remain available, and Federation Square remains the default starting point.

CLUE stands for Census of Land Use and Employment. `clue_areas.geojson` retains 13 statistical areas without simplifying their geometry. These areas cover multiple parts of the City of Melbourne, beyond the CBD, and are not equivalent to all suburb boundaries.

## Distances and limitations

GeoJSON coordinates are ordered as longitude, latitude. `venues_near()` uses Haversine straight-line distance with a mean Earth radius of 6,371,008.8 metres. It returns venues within the specified radius, adds `distance_m`, and sorts the results by distance.

At a radius of 600 metres, the checked results are 303 venues around Federation Square, 619 around State Library Victoria, and 65 shared venues. Run this example from the repository root:

```r
source("R/core/data.R")
source("R/core/geo.R")
data <- load_app_data("data")
fed_id <- unname(landmark_choices(data)[["Federation Square"]])
nrow(venues_near(data, fed_id, radius_m = 600))  # 303
```

The 1,994 venues have 1,133 distinct coordinate pairs. Multiple venues in a building may share a location. Use `venue_id` to identify venues; coordinates are unsuitable as a deduplication key and do not represent exact entrances.

The data does not provide opening hours, prices, or cuisines. Dining records are a historical snapshot. Straight-line distance does not represent a walking route or travel time.

## Sources and licence

All three source datasets are published by the City of Melbourne under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/). The snapshot applies category filtering, record merging, and format conversion as described above and in `manifest.json`.

- [Cafes and restaurants with seating capacity](https://data.melbourne.vic.gov.au/explore/dataset/cafes-and-restaurants-with-seating-capacity/information/), using 2024 records.
- [Landmarks and places of interest](https://data.melbourne.vic.gov.au/explore/dataset/landmarks-and-places-of-interest-including-schools-theatres-health-services-spor/information/).
- [Small areas for Census of Land Use and Employment](https://data.melbourne.vic.gov.au/explore/dataset/small-areas-for-census-of-land-use-and-employment-clue/information/).

Retain City of Melbourne attribution when reusing the data, together with source and licence links and a description of transformations. `manifest.json` records the original export URLs, download times, source file checksums, and checksums for the data files in this directory.
