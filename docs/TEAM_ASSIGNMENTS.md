# Module responsibilities and course deliverables

Each feature module has its own maintenance responsibility. Integration of the shared core is a separate responsibility. Current owners are listed below; unassigned roles remain vacant.

## Responsibility table

| Module | Owner | Main files | Feature scope |
|---|---|---|---|
| Area overview | Unassigned | `R/modules/area/`, `www/css/area.css` | Area map, area selection, dining overview, and Tableau chart |
| Nearby dining | Jun Xu | `R/modules/nearby/`, `www/css/nearby.css` | Landmark and radius selection, map, nearby list, and venue selection |
| Landmark comparison | Unassigned | `R/modules/compare/`, `www/css/compare.css` | Comparison with matching scope, category charts, and overlap identification |
| Venue details and shortlist | Unassigned | `R/modules/shortlist/`, `www/css/shortlist.css` | Venue details, shortlist management, and CSV export |
| Shared core integration | Unassigned | `app.R`, `R/core/`, `www/css/common.css` | Module interfaces, shared styles, dependencies, and application integration |

## Module collaboration

Modules read the shared `data` object and exchange selection and shortlist IDs through `state`. Interfaces are documented in the [architecture notes](ARCHITECTURE.md). The area overview's Tableau workbook directory is `tableau/`.

Changes to data definitions affect all modules. Record the affected fields and counts when making such changes. Changes to shared components or state fields require updates to the interface documentation and affected modules. Modules do not download or clean data independently.

## Course requirements and deliverables

The project is part of GEOM90007 Information Visualisation Assignment 3, Group 26. The final interface must use R Shiny and incorporate at least one Tableau visualisation using the methods from course section 8.5. The four modules form one application with consistent visuals and interactions.

Parts A and B are due on 3 November 2026 at 23:59, Australia/Sydney (AEDT). Part A requires a ZIP containing the application and all data needed to run it. The report PDF is submitted separately.

Official instructions are available in [Part A](https://canvas.lms.unimelb.edu.au/courses/241878/assignments/617019) and [Week 8.5 Tableau and Shiny integration](https://canvas.lms.unimelb.edu.au/courses/241878/pages/8-dot-5-pre-lab-tasks-integrating-tableau-into-shiny). Access requires the appropriate Canvas permissions.
