# Melbourne Dining Explorer

**GEOM90007 Information Visualisation · Group 26**

An R Shiny application for tourists planning sightseeing and dining in the City of
Melbourne. Four linked views explore dining by area, around a landmark, between
two landmarks, and along an ordered sightseeing route.

## Run

Install R, open a terminal in this folder, and run:

```sh
Rscript setup.R
```

The script prepares `shiny`, `jsonlite` and `shinyjs`, then starts the application
at **http://localhost:43873**. `config.json` contains the demo Google key, server
address, map provider, radius settings and route-scoring weights.

## Data and method

The bundled snapshot contains 1,994 dining venues, 242 landmarks and 13 CLUE areas.
Route suggestions combine straight-line insertion distance and preferred meal
position. The area overview embeds the group's Tableau workbook; restaurant
details use Google Places UI Kit.

- [City of Melbourne Open Data](https://data.melbourne.vic.gov.au/) · CLUE 2024 · CC BY 4.0
- [OpenStreetMap](https://www.openstreetmap.org/copyright) · ODbL
- [Project repository](https://github.com/scdxwyxj-ops/iv-a3-melbourne-dining-demo)

## Repository

`app.R` assembles the interface. `R/` contains shared functions and page modules;
`www/` contains browser code, styles and assets; `data/` contains runtime datasets.

## Contributions

| Member | GitHub | Responsibility |
| --- | --- | --- |
| Jun Xu | [scdxwyxj-ops](https://github.com/scdxwyxj-ops) | Feature 4: Dining along your route; shared core and application integration. |
| qingyiliu | [krystal00198](https://github.com/krystal00198) | Feature 1: Area overview. |
| R0nanYang | [R0nanYang](https://github.com/R0nanYang) | Feature 2: Near a landmark. |
| mngj506 | [mngj506](https://github.com/mngj506) | Feature 3: Compare places. |
