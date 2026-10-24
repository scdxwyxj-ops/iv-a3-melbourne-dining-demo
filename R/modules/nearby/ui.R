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
    select = ns("select_venue"), message = ns("map_update")
  ), auto_unbox = TRUE)
  javascript <- r"---(
(function(config) {
  let root, map, status, layers, circle, scope, latest;
  let groups = [], selected = null, initialised = false;
  const element = (tag, className, text) => {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  const choose = id => {
    if (window.Shiny) Shiny.setInputValue(config.select, id, {priority: 'event'});
  };
  function syncList(scroll) {
    const list = document.getElementById(config.list);
    if (!list) return;
    list.querySelectorAll('button[data-venue-id]').forEach(button => {
      const active = button.dataset.venueId === selected;
      button.classList.toggle('is-selected', active);
      button.setAttribute('aria-pressed', String(active));
      if (scroll && active) {
        list.scrollTop = button.offsetTop - list.clientHeight / 2 + button.offsetHeight / 2;
      }
    });
  }
  function icon(group) {
    const active = group.venues.some(v => v.venue_id === selected);
    const categories = new Set(group.venues.map(v => v.category_code));
    const category = categories.size > 1 ? 'mixed' : categories.has('4512') ? 'takeaway' : 'cafe';
    const size = group.venues.length > 1 ? 22 : 14;
    return L.divIcon({
      className: 'nearby-marker ' + category + (active ? ' is-selected' : ''),
      html: group.venues.length > 1 ? String(group.venues.length) : '',
      iconSize: [size, size], iconAnchor: [size / 2, size / 2]
    });
  }
  function popup(group) {
    const content = element('div', 'nearby-popup');
    content.appendChild(element('strong', 'nearby-popup-title',
      group.venues.length > 1 ? group.venues.length + ' venues at this location' : 'Dining venue'));
    group.venues.forEach(venue => {
      const button = element('button', 'nearby-popup-choice');
      button.type = 'button';
      button.dataset.venueId = venue.venue_id;
      button.setAttribute('aria-pressed', String(venue.venue_id === selected));
      button.appendChild(element('strong', '', venue.name));
      button.appendChild(element('span', '', venue.category + ' · ' + Math.round(venue.distance_m) + ' m'));
      button.addEventListener('click', () => choose(venue.venue_id));
      content.appendChild(button);
    });
    return content;
  }
  function fit() {
    if (!map || !circle) return;
    map.invalidateSize({pan: false});
    map.fitBounds(circle.getBounds(), {padding: [26, 26], maxZoom: 17, animate: false});
  }
  function update(message) {
    latest = message;
    if (!initialised) return;
    const changed = scope !== message.scope;
    const selectionChanged = selected !== message.selected;
    selected = message.selected;
    if (map && changed) {
      scope = message.scope;
      layers.clearLayers();
      const origin = message.origin;
      const colours = getComputedStyle(root);
      const teal = colours.getPropertyValue('--color-primary').trim();
      circle = L.circle([origin.latitude, origin.longitude], {
        radius: message.radius, color: teal, weight: 2, dashArray: '6 5',
        fillColor: teal, fillOpacity: 0.07, interactive: false
      }).addTo(layers);
      const locations = new Map();
      (message.venues || []).forEach(venue => {
        const key = venue.longitude + ',' + venue.latitude;
        if (!locations.has(key)) locations.set(key, {venues: []});
        locations.get(key).venues.push(venue);
      });
      groups = Array.from(locations.values());
      groups.forEach(group => {
        const venue = group.venues[0];
        const title = group.venues.length > 1 ? group.venues.length + ' venues at this location' : venue.name;
        group.marker = L.marker([venue.latitude, venue.longitude], {
          icon: icon(group), title, alt: title, keyboard: true
        }).addTo(layers);
        group.marker.bindPopup(() => popup(group), {maxWidth: 290, minWidth: 210});
        group.marker.on('click', () => {
          if (group.venues.length === 1) choose(venue.venue_id);
        });
        group.marker.getElement().addEventListener('keydown', event => {
          if (event.key !== 'Enter' && event.key !== ' ') return;
          event.preventDefault();
          event.stopPropagation();
          group.marker.openPopup();
          if (group.venues.length === 1) choose(venue.venue_id);
          else group.marker.getPopup().getElement().querySelector('button')?.focus();
        });
      });
      const originIcon = L.divIcon({className: 'nearby-origin', html: '<span aria-hidden="true">◆</span>',
        iconSize: [30, 30], iconAnchor: [15, 15]});
      L.marker([origin.latitude, origin.longitude], {
        icon: originIcon, title: origin.name, alt: origin.name, zIndexOffset: 2000
      }).addTo(layers).bindTooltip(element('span', '', origin.name), {direction: 'top'});
      fit();
    }
    if (map) groups.forEach(group => {
      const active = group.venues.some(v => v.venue_id === selected);
      group.marker.setIcon(icon(group));
      group.marker.setZIndexOffset(active ? 1000 : 0);
      if (active && selectionChanged) {
        if (!group.marker.isPopupOpen()) group.marker.openPopup();
        map.panInside(group.marker.getLatLng(), {padding: [28, 28]});
      }
      if (group.marker.isPopupOpen()) {
        group.marker.getPopup().getElement().querySelectorAll('button[data-venue-id]').forEach(button => {
          button.setAttribute('aria-pressed', String(button.dataset.venueId === selected));
        });
      }
    });
    if (map && !selected && selectionChanged) map.closePopup();
    syncList(selectionChanged);
  }
  function initialise() {
    if (initialised) return;
    root = document.getElementById(config.root);
    if (!root || typeof window.Shiny?.setInputValue !== 'function') return;
    initialised = true;
    status = document.getElementById(config.status);
    root.addEventListener('click', event => {
      const button = event.target.closest('.nearby-venue[data-venue-id]');
      if (button && root.contains(button)) choose(button.dataset.venueId);
    });
    new MutationObserver(() => syncList(false)).observe(document.getElementById(config.list), {childList: true, subtree: true});
    if (window.L) {
      map = L.map(config.map, {scrollWheelZoom: false, maxZoom: 19}).setView([-37.8179, 144.9691], 15);
      layers = L.layerGroup().addTo(map);
      const tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(map);
      tiles.on('tileerror', () => {
        status.hidden = false;
        status.textContent = 'Street tiles could not load. Dining markers and the results list are still available.';
      });
      tiles.on('load', () => {
        if (root.querySelector('.leaflet-tile-loaded')) status.hidden = true;
      });
      L.control.scale({imperial: false, position: 'bottomleft'}).addTo(map);
      document.getElementById(config.fit).addEventListener('click', fit);
      new ResizeObserver(() => map.invalidateSize({pan: false})).observe(document.getElementById(config.map));
      status.hidden = true;
    } else {
      status.textContent = 'The map could not load. Check your connection; you can still select venues from the list.';
      document.getElementById(config.fit).disabled = true;
    }
    Shiny.setInputValue(config.ready, true, {priority: 'event'});
    if (latest) update(latest);
  }
  Shiny.addCustomMessageHandler(config.message, update);
  $(initialise);
  $(document).on('shiny:connected', () => {
    initialise();
    Shiny.setInputValue(config.ready, true, {priority: 'event'});
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
        div(h1("Find dining near a landmark"), p("Choose a starting point and explore dining within a straight-line radius.")),
        div(class = "feature-meta", span(class = "status-pill nearby-status", "Interactive map"))
      ),
      div(class = "feature-layout nearby-layout",
        panel_card("Choose a starting point", class = "control-panel",
          div(class = "nearby-landmark-picker",
            selectizeInput(ns("landmark"), "Landmark", choices = choices,
              selected = unname(choices[["Federation Square"]]),
              options = list(create = FALSE, onInitialize = landmark_search))),
          sliderInput(ns("radius"), "Radius (metres)", min = 200, max = 1200, value = 600, step = 100),
          p(class = "help-copy", "Distances are measured in a straight line from the landmark, not along walking routes."),
          div(class = "nearby-selection", h3("Selected venue"), uiOutput(ns("selection")))
        ),
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
        panel_card("Nearby dining", class = "summary-panel",
          uiOutput(ns("count")),
          p(class = "nearby-list-caption", "Nearest first · select a venue"),
          div(id = ns("venues"), class = "nearby-list", `aria-label` = "Nearby dining results", uiOutput(ns("list")))
        )
      )
    ),
    tags$script(HTML(paste0(javascript, config, ");")))
  )
}
