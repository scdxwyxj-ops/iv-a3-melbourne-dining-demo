# Shared design language

The interface uses a light background and white cards. On desktop layouts, controls sit on the left, the map region occupies the centre, and summaries or results appear on the right. Shared styles are defined in `www/css/common.css`; module adjustments use their corresponding CSS files.

## Colours

| CSS token | Value | Purpose |
|---|---|---|
| `--color-primary` | `#087f80` | Primary actions, cafes and restaurants, and comparison A |
| `--color-secondary` | `#7961b0` | Comparison B and overlap summaries |
| `--color-takeaway` | `#db8950` | Takeaway category markers |
| `--color-text` | `#203b36` | Body text and headings |
| `--color-muted` | `#657970` | Supporting text |
| `--color-background` | `#f6f8f6` | Page background |
| `--color-surface` | `#ffffff` | Card background |
| `--color-border` | `#dce6e0` | Card and control borders |

Category colours stay consistent across all four pages. Comparisons also label A and B in text. Orange marks takeaway venues; body text and buttons use the shared text and primary colours.

## Typography and layout

The font stack uses Arial and system sans-serif fonts. Page headings are 25px, card headings 15px, body text 14px, and supporting text 12px. Metric values are 42px, or 34px in the two-column comparison cards.

Cards have a 12px corner radius, with 7px for controls. Card spacing is 16px and padding is 20px. The desktop control column is 235px wide, the summary column is 310px, and the map column fills the remaining space. Narrower windows use two columns or one column.

## Shared components

| Component | Content convention |
|---|---|
| `feature_heading()` | Task title, short description, placeholder status, and owner |
| `panel_card()` | A card with one purpose and an h2 heading |
| `placeholder_canvas()` | An explicitly labelled implementation area with no invented map or data points |
| `metric_card()` | A value, its unit or subject, and any required scope note |
| `category_legend()` | The fixed legend for the two dining categories |
| `next_step_note()` | Development notes for the placeholder version; remove from the final user interface |

## Interface text and interactions

The interface and repository documentation use English. Page headings describe the current task, and controls retain visible labels.

- Count venues using the one-venue-per-row records, not seating rows or distinct coordinates.
- Use metres for radius units and straight-line for distance descriptions.
- Display missing seating as Unknown; display 0 when the recorded value is zero.
- Show an empty state for zero results and suggest adjusting the landmark or radius.
- Disable unimplemented buttons and label them coming next.
- Render venue names and addresses as plain text. Avoid inserting unescaped source data into HTML.

Maps require a legend and a census year note. Venues with shared coordinates retain separate identities. Distances are not described as walking routes.

## Chart scope

Comparison charts use the same category order and scale. Venue counts are not labelled as density. Chart filters and page controls use the same data scope. See the [workbook notes](../tableau/README.md) for Tableau integration conventions.
