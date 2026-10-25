# Browser map: Leaflet 1.9.4 (https://leafletjs.com/reference.html), BSD-2-Clause.
# Shiny owns filtering and shared state; this adapter handles map and list events.
# Leaflet assets and OpenStreetMap tiles require an internet connection.
nearby_ui <- function(id, data) {
  ns <- NS(id)
  choices <- landmark_choices(data)
  landmark_search <- I(r"---(function() {
    const control = this;
    const header = $('<label class="nearby-landmark-search">Search landmarks</label>');
    const search = $('<input type="search" placeholder="Type a landmark name…" autocomplete="off" aria-label="Search landmarks">');
    const empty = $('<div class="nearby-landmark-empty" role="status" hidden>No matching landmarks</div>');
    header.append(search);
    control.$dropdown.prepend(header).append(empty);
    function filter() {
      const query = search.val().trim().toLocaleLowerCase();
      const options = control.$dropdown_content.find('[data-value]');
      options.each(function() {
        const matches = $(this).text().toLocaleLowerCase().includes(query);
        $(this).toggle(matches);
        if (matches) $(this).attr('data-selectable', '');
        else $(this).removeAttr('data-selectable');
      });
      const matches = options.filter('[data-selectable]');
      control.hasOptions = matches.length > 0;
      control.setActiveOption(matches.first());
      empty.prop('hidden', matches.length > 0);
      control.positionDropdown();
    }
    // Keep the dropdown open when focus moves from Selectize to its search field.
    const originalBlur = control.onBlur;
    control.onBlur = function(event, destination) {
      if (event && event.relatedTarget === search[0]) return;
      return originalBlur.call(control, event, destination);
    };
    search.on('mousedown', event => event.stopPropagation());
    search.on('input', filter);
    search.on('blur', function(event) {
      if (!control.$dropdown[0].contains(event.relatedTarget)) control.onBlur(event);
    });
    search.on('keydown', function(event) {
      if (![13, 27, 38, 40].includes(event.keyCode)) return;
      control.onKeyDown(event);
      if (event.keyCode === 27) {
        control.ignoreFocus = true;
        control.$control_input[0].focus();
        control.ignoreFocus = false;
      }
    });
    control.on('dropdown_open', function() {
      search.val('');
      filter();
      setTimeout(() => { if (control.isOpen) search[0].focus(); }, 0);
    });
  })---")
  config <- jsonlite::toJSON(list(
    root = ns("module"), map = ns("map"), status = ns("map_status"),
    list = ns("venues"), fit = ns("fit"), ready = ns("map_ready"),
    select = ns("select_venue"), message = ns("map_update"), reveal = ns("reveal_selection"),
    curveInput = ns("chart_radius"), curveOutput = ns("curve"), scatterOutput = ns("scatter"),
    radiusPreview = ns("radius_preview"), pointReadout = ns("point_readout"), pointChoices = ns("point_choices")
  ), auto_unbox = TRUE)
  javascript <- r"---(
(function(config) {
  let root, map, status, layers, circle, scope, latest;
  let groups = [], selected = null, initialised = false;
  let pendingFit = false, pendingReveal = false, radiusKeyboardActive = false;
  const element = (tag, className, text) => {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  const get = key => document.getElementById(config[key]);
  const venueById = id => (latest?.venues || []).find(v => v.venue_id === id);
  const choose = id => Shiny.setInputValue(config.select, id, {priority: 'event'});
  const seatLabel = value => Number.isFinite(value) ? String(value) : 'Unrecorded';
  function syncSelection(scroll) {
    get('list')?.querySelectorAll('button[data-venue-id]').forEach(button => {
      const active = button.dataset.venueId === selected;
      button.classList.toggle('is-selected', active);
      button.setAttribute('aria-pressed', String(active));
      if (scroll && active && get('list').clientHeight) get('list').scrollTop = button.offsetTop - get('list').clientHeight / 2 + button.offsetHeight / 2;
    });
    const points = [...root.querySelectorAll('.nearby-scatter-point')];
    const activePoint = points.find(p => p.dataset.venueId === selected);
    points.forEach((point, index) => {
      const active = point === activePoint;
      point.classList.toggle('is-selected', active);
      point.setAttribute('aria-pressed', String(active));
      point.setAttribute('r', active ? '6' : '4.5');
      point.setAttribute('tabindex', active || (!activePoint && index === 0) ? '0' : '-1');
    });
    root.querySelectorAll('.nearby-plot-choice').forEach(button => {
      button.setAttribute('aria-pressed', String(button.dataset.venueId === selected));
    });
    if (radiusKeyboardActive) {
      const replacement = root.querySelector('.nearby-radius-hit');
      if (replacement && replacement.getClientRects().length && document.activeElement !== replacement) {
        replacement.focus({preventScroll: true});
      }
    }
    const readout = get('pointReadout');
    if (readout && !readout.dataset.ready) {
      readout.dataset.ready = 'true';
      pointInfo(venueById(selected));
    }
  }
  function pointInfo(venue) {
    const node = get('pointReadout');
    if (!node) return;
    if (!venue) {
      node.textContent = 'Hover for venue details. Select a point to link it to the map and list.';
      return;
    }
    node.replaceChildren(element('strong', '', venue.name), element('span', '',
      Math.round(venue.distance_m) + ' m · ' + seatLabel(venue.indoor_seats) +
      (Number.isFinite(venue.indoor_seats) ? ' recorded indoor seats' : ' indoor seats; not plotted')));
  }
  function plotChoice(point, event) {
    // Resolve visual overlaps in screen pixels, without moving or dropping data.
    const svg = point.ownerSVGElement;
    const transform = svg.getScreenCTM();
    const tolerance = Math.max(8, Number(point.getAttribute('r')) * Math.hypot(transform.a, transform.b) + 3);
    const peers = [...root.querySelectorAll('.nearby-scatter-point')].filter(p => {
      const position = svg.createSVGPoint();
      position.x = Number(p.getAttribute('cx')); position.y = Number(p.getAttribute('cy'));
      const screen = position.matrixTransform(transform);
      return Math.hypot(screen.x - event.clientX, screen.y - event.clientY) <= tolerance;
    });
    const box = get('pointChoices');
    box.replaceChildren();
    if (peers.length === 1) {
      choose(point.dataset.venueId);
      return;
    }
    box.appendChild(element('strong', 'nearby-overlap-label', peers.length + ' venues overlap near this point. Choose one:'));
    peers.forEach(peer => {
      const venue = venueById(peer.dataset.venueId);
      if (!venue) return;
      const button = element('button', 'nearby-plot-choice', venue.name);
      button.type = 'button'; button.dataset.venueId = venue.venue_id;
      button.title = venue.address;
      button.setAttribute('aria-label', venue.name + ', ' + venue.address);
      button.setAttribute('aria-pressed', String(venue.venue_id === selected));
      box.appendChild(button);
    });
    box.querySelector('button')?.focus({preventScroll: true});
  }
  function radiusAt(event, hit) {
    const svg = hit.ownerSVGElement;
    const point = svg.createSVGPoint();
    point.x = event.clientX; point.y = event.clientY;
    const x = point.matrixTransform(svg.getScreenCTM().inverse()).x;
    return Math.max(200, Math.min(1200, Math.round((x - 65) / 531 * 12) * 100));
  }
  function radiusPreview(radius, hit) {
    const counts = JSON.parse(hit.dataset.counts);
    get('radiusPreview').textContent = radius + ' m · ' + counts[radius / 100] + ' venues · click to apply';
  }
  function setRadius(radius, keyboardTarget) {
    if (keyboardTarget && Number(keyboardTarget.dataset.radius) === radius) return;
    if (keyboardTarget) radiusKeyboardActive = true;
    Shiny.setInputValue(config.curveInput, radius, {priority: 'event'});
  }
  function icon(group) {
    const active = group.venues.some(v => v.venue_id === selected);
    const categories = new Set(group.venues.map(v => v.category_code));
    const category = categories.size > 1 ? 'mixed' : categories.has('4512') ? 'takeaway' : 'cafe';
    const size = group.venues.length > 1 ? 22 : 14;
    return L.divIcon({className: 'nearby-marker ' + category + (active ? ' is-selected' : ''),
      html: group.venues.length > 1 ? String(group.venues.length) : '',
      iconSize: [size, size], iconAnchor: [size / 2, size / 2]});
  }
  function seatingDetail(venue) {
    const content = element('div', 'nearby-popup-seating');
    content.append(element('strong', 'nearby-popup-name', venue.name),
      element('p', 'nearby-popup-meta', venue.category + ' · ' + Math.round(venue.distance_m) + ' m'),
      element('p', 'nearby-popup-address', venue.address),
      element('strong', 'nearby-popup-title', 'Recorded seating · 2024'));
    const known = [venue.indoor_seats, venue.outdoor_seats].filter(Number.isFinite);
    const maximum = Math.max(10, Math.ceil(Math.max(0, ...known) / 10) * 10);
    [['Indoor', venue.indoor_seats], ['Outdoor', venue.outdoor_seats]].forEach(([label, value]) => {
      const row = element('div', 'nearby-seat-row');
      const labels = element('div', 'nearby-seat-labels');
      labels.append(element('span', '', label), element('strong', '', seatLabel(value)));
      const track = element('div', 'nearby-seat-track' + (Number.isFinite(value) ? '' : ' is-unknown'));
      track.setAttribute('aria-hidden', 'true');
      if (Number.isFinite(value)) {
        const bar = element('span', 'nearby-seat-bar'); bar.style.width = value / maximum * 100 + '%'; track.appendChild(bar);
      }
      row.append(labels, track); content.appendChild(row);
    });
    content.appendChild(element('p', 'nearby-popup-note', 'Bars: 0–' + maximum + ' seats. Historical capacity, not live availability.'));
    return content;
  }
  function syncPopup(group) {
    const node = group.marker.getPopup()?.getElement();
    if (!node) return;
    const venue = group.venues.find(v => v.venue_id === selected) || (group.venues.length === 1 ? group.venues[0] : null);
    const detail = node.querySelector('.nearby-popup-detail');
    if (detail && detail.dataset.venueId !== (venue?.venue_id || '')) {
      detail.dataset.venueId = venue?.venue_id || '';
      detail.replaceChildren(...(venue ? [seatingDetail(venue)] : []));
      if (venue) detail.closest('.nearby-popup').scrollTop = 0;
    }
    node.querySelectorAll('button[data-venue-id]').forEach(button => {
      button.setAttribute('aria-pressed', String(button.dataset.venueId === selected));
    });
  }
  function popup(group) {
    const content = element('div', 'nearby-popup');
    const detail = element('div', 'nearby-popup-detail');
    const venue = group.venues.find(v => v.venue_id === selected) || (group.venues.length === 1 ? group.venues[0] : null);
    detail.dataset.venueId = venue?.venue_id || '';
    if (venue) detail.appendChild(seatingDetail(venue));
    content.appendChild(detail);
    if (group.venues.length > 1) content.appendChild(element('strong', 'nearby-popup-title', group.venues.length + ' venues at this location'));
    group.venues.forEach(venue => {
      const button = element('button', 'nearby-popup-choice'); button.type = 'button'; button.dataset.venueId = venue.venue_id;
      button.setAttribute('aria-pressed', String(venue.venue_id === selected));
      button.append(element('strong', '', venue.name), element('span', '', venue.category + ' · ' + Math.round(venue.distance_m) + ' m'));
      button.addEventListener('click', () => choose(venue.venue_id)); content.appendChild(button);
    });
    return content;
  }
  function mapVisible() { return map && get('map').clientWidth > 0 && get('map').clientHeight > 0; }
  function fit() {
    if (!map || !circle) return;
    if (!mapVisible()) { pendingFit = true; return; }
    map.invalidateSize({pan: false});
    map.fitBounds(circle.getBounds(), {padding: [26, 26], maxZoom: 17, animate: false}); pendingFit = false;
  }
  function reveal() {
    if (!mapVisible()) { pendingReveal = true; return; }
    const group = groups.find(g => g.venues.some(v => v.venue_id === selected));
    if (group) {
      if (!group.marker.isPopupOpen()) group.marker.openPopup();
      syncPopup(group); map.panInside(group.marker.getLatLng(), {padding: [28, 28]});
    }
    pendingReveal = false;
  }
  function resizeMap() {
    if (!mapVisible()) return;
    map.invalidateSize({pan: false});
    if (pendingFit) fit();
    if (pendingReveal) reveal();
    if (selected) syncSelection(true);
  }
  function update(message) {
    latest = message;
    if (!initialised) return;
    const changed = scope !== message.scope;
    const selectionChanged = selected !== message.selected;
    selected = message.selected;
    const choices = get('pointChoices');
    const belongsToChoices = choices && [...choices.querySelectorAll('[data-venue-id]')].some(b => b.dataset.venueId === selected);
    if (changed || (selectionChanged && !belongsToChoices)) choices?.replaceChildren();
    if (map && changed) {
      scope = message.scope; layers.clearLayers();
      const origin = message.origin;
      const teal = getComputedStyle(root).getPropertyValue('--color-primary').trim();
      circle = L.circle([origin.latitude, origin.longitude], {radius: message.radius, color: teal,
        weight: 2, dashArray: '6 5', fillColor: teal, fillOpacity: 0.07, interactive: false}).addTo(layers);
      const locations = new Map();
      (message.venues || []).forEach(venue => {
        const key = venue.longitude + ',' + venue.latitude;
        if (!locations.has(key)) locations.set(key, {venues: []}); locations.get(key).venues.push(venue);
      });
      groups = Array.from(locations.values());
      groups.forEach(group => {
        const venue = group.venues[0];
        const title = group.venues.length > 1 ? group.venues.length + ' venues at this location' : venue.name;
        group.marker = L.marker([venue.latitude, venue.longitude], {icon: icon(group), title, alt: title, keyboard: true}).addTo(layers);
        group.marker.bindPopup(() => popup(group), {maxWidth: 300, minWidth: 235});
        group.marker.on('click', () => { if (group.venues.length === 1) choose(venue.venue_id); });
        group.marker.getElement().addEventListener('keydown', event => {
          if (event.key !== 'Enter' && event.key !== ' ') return;
          event.preventDefault(); event.stopPropagation(); group.marker.openPopup();
          if (group.venues.length === 1) choose(venue.venue_id);
          else group.marker.getPopup().getElement().querySelector('button')?.focus();
        });
      });
      const originIcon = L.divIcon({className: 'nearby-origin', html: '<span aria-hidden="true">◆</span>', iconSize: [30, 30], iconAnchor: [15, 15]});
      L.marker([origin.latitude, origin.longitude], {icon: originIcon, title: origin.name, alt: origin.name, zIndexOffset: 2000})
        .addTo(layers).bindTooltip(element('span', '', origin.name), {direction: 'top'});
      fit(); if (selected) pendingReveal = true;
    }
    if (map) {
      groups.forEach(group => {
        const active = group.venues.some(v => v.venue_id === selected);
        group.marker.setIcon(icon(group)); group.marker.setZIndexOffset(active ? 1000 : 0);
        if (group.marker.isPopupOpen()) syncPopup(group);
      });
      if (selected && selectionChanged) { pendingReveal = true; reveal(); }
      if (!selected && selectionChanged) { map.closePopup(); pendingReveal = false; }
    }
    syncSelection(selectionChanged); pointInfo(venueById(selected));
  }
  function initialise() {
    if (initialised) return;
    root = get('root'); if (!root || typeof window.Shiny?.setInputValue !== 'function') return;
    initialised = true; status = get('status');
    document.addEventListener('focusin', event => {
      radiusKeyboardActive = root.contains(event.target) && event.target.matches('.nearby-radius-hit');
    });
    document.addEventListener('pointerdown', event => {
      if (!event.target.closest('.nearby-radius-hit')) radiusKeyboardActive = false;
    });
    root.addEventListener('click', event => {
      const button = event.target.closest('.nearby-venue[data-venue-id], .nearby-plot-choice[data-venue-id]');
      if (button) { choose(button.dataset.venueId); return; }
      const point = event.target.closest('.nearby-scatter-point');
      if (point) { plotChoice(point, event); return; }
      const hit = event.target.closest('.nearby-radius-hit');
      if (hit) setRadius(radiusAt(event, hit));
    });
    root.addEventListener('pointermove', event => {
      const hit = event.target.closest('.nearby-radius-hit');
      if (hit) radiusPreview(radiusAt(event, hit), hit);
    });
    root.addEventListener('pointerover', event => {
      const point = event.target.closest('.nearby-scatter-point'); if (point) pointInfo(venueById(point.dataset.venueId));
    });
    root.addEventListener('pointerout', event => {
      if (event.target.closest('.nearby-scatter-point')) pointInfo(venueById(selected));
      const hit = event.target.closest('.nearby-radius-hit'); if (hit) radiusPreview(Number(hit.dataset.radius), hit);
    });
    root.addEventListener('focusin', event => {
      const point = event.target.closest('.nearby-scatter-point');
      if (point) {
        root.querySelectorAll('.nearby-scatter-point').forEach(p => p.setAttribute('tabindex', p === point ? '0' : '-1'));
        pointInfo(venueById(point.dataset.venueId));
      }
    });
    root.addEventListener('keydown', event => {
      const hit = event.target.closest('.nearby-radius-hit');
      if (hit && event.key === 'Tab') radiusKeyboardActive = false;
      if (hit && ['ArrowLeft','ArrowDown','ArrowRight','ArrowUp','Home','End'].includes(event.key)) {
        event.preventDefault(); event.stopPropagation();
        const change = ['ArrowLeft','ArrowDown'].includes(event.key) ? -100 : 100;
        const radius = event.key === 'Home' ? 200 : event.key === 'End' ? 1200 : Math.max(200, Math.min(1200, Number(hit.dataset.radius) + change));
        setRadius(radius, hit); return;
      }
      const point = event.target.closest('.nearby-scatter-point'); if (!point) return;
      if (['Enter',' '].includes(event.key)) { event.preventDefault(); choose(point.dataset.venueId); return; }
      if (['ArrowLeft','ArrowDown','ArrowRight','ArrowUp','Home','End'].includes(event.key)) {
        event.preventDefault(); const points = [...root.querySelectorAll('.nearby-scatter-point')];
        const index = points.indexOf(point) + (['ArrowLeft','ArrowUp'].includes(event.key) ? -1 : 1);
        const next = event.key === 'Home' ? 0 : event.key === 'End' ? points.length - 1 : Math.max(0, Math.min(points.length - 1, index));
        points[next]?.focus({preventScroll: true});
      }
    });
    new MutationObserver(() => syncSelection(false)).observe(get('list'), {childList: true, subtree: true});
    [get('curveOutput'), get('scatterOutput')].forEach(node => {
      new MutationObserver(() => syncSelection(false)).observe(node, {childList: true, subtree: true});
    });
    $(document).on('shown.bs.tab', resizeMap);
    if (window.L) {
      map = L.map(config.map, {scrollWheelZoom: false, maxZoom: 19}).setView([-37.8179, 144.9691], 15);
      layers = L.layerGroup().addTo(map); let tileFailures = 0;
      const tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);
      tiles.on('loading', () => { tileFailures = 0; });
      tiles.on('tileerror', () => {
        tileFailures++; status.hidden = false;
        status.textContent = 'Street tiles could not load. Dining markers and the results list are still available.';
      });
      tiles.on('load', () => { if (!tileFailures && root.querySelector('.leaflet-tile-loaded')) status.hidden = true; });
      L.control.scale({imperial: false, position: 'bottomleft'}).addTo(map);
      get('fit').addEventListener('click', fit);
      new ResizeObserver(resizeMap).observe(get('map')); status.hidden = true;
    } else {
      status.textContent = 'The map could not load. Check your connection; the list and analysis charts are still available.';
      get('fit').disabled = true;
    }
    Shiny.setInputValue(config.ready, true, {priority: 'event'});
    if (latest) update(latest);
  }
  Shiny.addCustomMessageHandler(config.message, update);
  Shiny.addCustomMessageHandler(config.reveal, message => { pendingReveal = true; reveal(); });
  $(initialise);
  $(document).on('shiny:connected', () => {
    initialise(); Shiny.setInputValue(config.ready, true, {priority: 'event'});
  });
})(
)---"
  tagList(
    tags$head(
      tags$link(rel = "stylesheet", href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css",
        integrity = "sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=", crossorigin = "anonymous"),
      tags$script(src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js",
        integrity = "sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=", crossorigin = "anonymous")
    ),
    div(id = ns("module"), class = "nearby-module",
      div(class = "feature-heading",
        div(h1("Find dining near a landmark"), p("Explore locations, adjust your search distance and compare recorded seating.")),
        div(class = "feature-meta", span(class = "status-pill nearby-status", "Linked views · 2024 census"))
      ),
      div(class = "feature-layout nearby-layout",
        panel_card("Choose a starting point", class = "control-panel",
          div(class = "nearby-landmark-picker",
            selectizeInput(ns("landmark"), "Landmark", choices = choices,
              selected = unname(choices[["Federation Square"]]),
              options = list(create = FALSE, onInitialize = landmark_search))),
          sliderInput(ns("radius"), "Radius (metres)", min = 200, max = 1200, value = 600, step = 100),
          p(class = "help-copy", "Distances are straight-line estimates from the landmark, not walking routes."),
          div(class = "nearby-selection", h3("Selected venue"), uiOutput(ns("selection")))
        ),
        div(class = "nearby-workspace",
          uiOutput(ns("count")),
          div(class = "nearby-view-tabs",
            tabsetPanel(id = ns("view"), type = "tabs", selected = "map",
              tabPanel("Map & list", value = "map",
                div(class = "nearby-map-layout",
                  panel_card("Nearby map", class = "nearby-map-panel",
                    div(class = "nearby-map-toolbar", uiOutput(ns("map_caption")),
                      tags$button(id = ns("fit"), type = "button", class = "btn btn-default nearby-fit", "Fit search area")),
                    div(class = "nearby-map-wrap",
                      div(id = ns("map"), class = "nearby-map", role = "region", `aria-label` = "Map of dining venues around the selected landmark"),
                      p(id = ns("map_status"), class = "nearby-map-status", role = "status", "Loading map…")),
                    div(class = "nearby-legend", category_legend(),
                      span(class = "nearby-origin-key", span(`aria-hidden` = "true", "◆"), "Selected landmark")),
                    p(class = "nearby-map-note", "Dining census · 2024. Numbered markers contain multiple venues at the same location.")
                  ),
                  panel_card("Nearby dining", class = "summary-panel nearby-results-panel",
                    p(class = "nearby-list-caption", "Nearest first · select a venue"),
                    div(id = ns("venues"), class = "nearby-list", `aria-label` = "Nearby dining results", uiOutput(ns("list")))
                  )
                )
              ),
              tabPanel("Distance & seating", value = "patterns",
                div(class = "nearby-analysis-layout",
                  panel_card("How many options within a larger radius?", class = "nearby-analysis-card",
                    p(id = ns("curve_hint"), class = "nearby-chart-intro", "Click the curve to set a radius. Arrow keys adjust it by 100 m."),
                    p(class = "nearby-chart-scroll-note", "Swipe sideways inside the chart to see the full range."),
                    div(class = "nearby-curve-legend",
                      span(span(class = "nearby-line-key"), "All recorded venues"),
                      span(span(class = "nearby-guide-key"), "Current radius")),
                    uiOutput(ns("curve")),
                    p(class = "nearby-data-note", "The curve previews all recorded venues within 1,200 m. The guide marks the current radius; it shows counts, not density.")
                  ),
                  panel_card("Compare distance and recorded capacity", class = "nearby-analysis-card",
                    p(class = "nearby-chart-intro", "Each point is a venue. Click to select; arrow keys move between points and Enter selects."),
                    p(class = "nearby-chart-scroll-note", "Swipe sideways inside the chart to see the full range."),
                    category_legend(), uiOutput(ns("scatter"))
                  )
                ),
                p(class = "nearby-analysis-footnote", "Both views share the selected landmark and venue. Use Show on map to locate a selected point. Records do not establish current opening status, visitor access or seat availability.")
              )
            )
          )
        )
      )
    ),
    tags$script(HTML(paste0(javascript, config, ");")))
  )
}
