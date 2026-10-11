# AI use statement

On 11 October 2026, OpenAI Codex assisted with the initial Shiny scaffold, data snapshot preparation, and project documentation.

## Scope of use

| Content | AI assistance |
|---|---|
| Application scaffold | Four Shiny modules, shared components, session state, and data loading functions |
| Styles | Shared colours, card layouts, and module CSS |
| Geographic calculations | Haversine straight-line distances and queries for venues within a radius |
| Data snapshot | Category filtering, indoor and outdoor seating record merging, format conversion, and source manifest |
| Documentation | READMEs, interface notes, design guidelines, responsibility table, integration notes, and English translation |

The documentation is written for public repository readers. Earlier Chinese drafts were reviewed with the `lieflat-less-ai-tone` skill, which checks only the writing issues listed in that skill. Repository documentation is now maintained in English.

## Verification record

Dining data checks covered the 3,249 original rows, 2,893 selected seating records, and 1,994 merged venues. At a 600-metre radius, Federation Square and State Library Victoria contain 303 and 619 venues respectively, with 65 shared venues. Data checks and file SHA-256 values are recorded in `data/manifest.json`.

The Shiny scaffold was checked for data loading, control responses, and session state isolation. Browser checks covered navigation across four pages, count previews, disabled placeholder buttons, and narrow-window layouts. No JavaScript errors were observed. A fresh GitHub clone loads the application without processing raw data.

The data loading examples can be run from the repository root; see the [data documentation](../data/README.md).

## Implementation and attribution status

Maps and charts remain placeholders, shortlist interactions are not implemented, and no user research has been conducted. AI-generated content does not establish completed Tableau integration or user evaluation.

Tableau integration references Alan Thomas's course examples (September 2024). The current application does not copy that integration library. Future use of course or external code should record its author, source, and modifications.

The final course submission must still acknowledge AI and external materials in an appropriate location in the code, interface, or design report, as required by the assignment. This statement records the initial version's scope of use and should be updated for subsequent work.
