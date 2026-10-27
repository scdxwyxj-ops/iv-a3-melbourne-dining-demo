import {
  TableauEventType,
  SelectionUpdateType,
  FilterUpdateType,
} from 'https://public.tableau.com/javascripts/api/tableau.embedding.3.latest.js';

const areaAliases = JSON.parse(document.getElementById('core-dataset-catalog').textContent).datasets
  .tableau_overview.area_aliases;
const viz = document.getElementById('overview-tableau');
const status = document.getElementById('overview-sync-status');
let ready = false;
let pendingArea = null;
let running = false;
let currentArea = null;
let selectionRead = 0;
let consistencyTimer;

// Public may retain its toolbar even when toolbar="hidden" is requested.

function checkConsistency() {
  clearTimeout(consistencyTimer);
  consistencyTimer = setTimeout(async () => {
    if (!ready || running || !currentArea) return;
    const read = selectionRead;
    try {
      const types = viz.workbook.activeSheet.worksheets.find(
        (sheet) => sheet.name === 'Venue types',
      );
      const filters = await types.getFiltersAsync();
      if (running || read !== selectionRead) return;
      const filter = filters.find((item) => item.fieldName === 'Area');
      const expected = areaAliases[currentArea] || currentArea;
      if (
        !filter ||
        filter.isAllSelected ||
        filter.appliedValues.length !== 1 ||
        filter.appliedValues[0].value !== expected
      ) {
        pendingArea = currentArea;
        synchronize();
      }
    } catch (error) {
      status.textContent = 'Select an area to refresh chart synchronisation.';
      console.error('Overview chart consistency:', error);
    }
  }, 200);
}
viz.addEventListener(TableauEventType.ToolbarStateChanged, checkConsistency);
viz.addEventListener(TableauEventType.FilterChanged, checkConsistency);

// Serialize updates; if the user switches quickly, finish on the newest area.
async function synchronize() {
  if (!ready || running || !pendingArea) return;
  running = true;
  try {
    while (pendingArea) {
      const area = pendingArea;
      pendingArea = null;
      // Tableau uses these display aliases for the two West Melbourne members.
      const member = areaAliases[area] || area;
      status.textContent = `Updating charts for ${area}…`;
      const sheets = viz.workbook.activeSheet.worksheets;
      const ranking = sheets.find((sheet) => sheet.name === 'Dining venues by area');
      const types = sheets.find((sheet) => sheet.name === 'Venue types');
      if (!ranking || !types)
        throw new Error('Use the Dining venues by area and Venue types worksheets.');
      await ranking.selectMarksByValueAsync(
        [{ fieldName: 'Area', value: [member] }],
        SelectionUpdateType.Replace,
      );
      await types.applyFilterAsync('Area', [member], FilterUpdateType.Replace);
      status.textContent = `Venue types in ${area}`;
    }
  } catch (error) {
    status.textContent = 'Chart sync failed. Select an area again to retry.';
    console.error('Overview Tableau synchronization:', error);
  } finally {
    running = false;
  }
}

Shiny.addCustomMessageHandler('overview-area', (message) => {
  selectionRead += 1;
  currentArea = message.area;
  pendingArea = message.area;
  synchronize();
});

viz.addEventListener(TableauEventType.MarkSelectionChanged, async (event) => {
  if (!ready || running || event.detail.worksheet.name !== 'Dining venues by area') return;
  const read = ++selectionRead;
  try {
    const marks = await event.detail.getMarksAsync();
    if (read !== selectionRead || running) return;
    const members = new Set();
    for (const table of marks.data) {
      const index = table.columns.findIndex((column) => column.fieldName === 'Area');
      if (index >= 0) for (const row of table.data) members.add(row[index].value);
    }
    if (members.size === 1) {
      Shiny.setInputValue('overview_chart_area', [...members][0], { priority: 'event' });
    }

    pendingArea = members.size === 1 ? [...members][0] : currentArea;
    synchronize();
  } catch (error) {
    status.textContent = 'Select an area from the dropdown to refresh chart selection.';
    console.error('Overview chart selection:', error);
  }
});
viz.addEventListener(TableauEventType.FirstInteractive, () => {
  ready = true;
  Shiny.setInputValue('overview_tableau_ready', true, { priority: 'event' });
  synchronize();
});
