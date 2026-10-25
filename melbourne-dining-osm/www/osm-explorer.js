/* Leaflet/OSM + Google Places UI Kit. No REST/fetchFields fallback, scraping,
   persistent restaurant storage or server-key transmission. */
(() => {
  'use strict';
  const el = id => document.getElementById(id);
  const send = (name, value) => window.Shiny.setInputValue(name, value, {priority:'event'});
  let initialized = false, ready = false, failed = false, map, circle, bounds, layer;
  let scene = null, generation = 0, activeWidget = null, selected = '', detailRequest = null;
  let fetched = null, searchTimer, loadTimer, detailTimer, detailCalls = 0, searchCalls = 0, limit = 15;
  const landmarks = new Map(), restaurants = new Map();
  const status = (text, error = false) => {
    el('live-status').textContent = text;
    el('live-status').className = 'status-message' + (error ? ' error' : '');
  };
  const day = date => new Intl.DateTimeFormat('en-CA', {timeZone:'Australia/Melbourne'}).format(date);
  const expired = () => fetched && (Date.now() - fetched.getTime() >= 900000 || day(fetched) !== day(new Date()));
  function button() { el('search').disabled = !ready || !scene?.landmark || Boolean(searchTimer) || searchCalls >= limit; }
  function clearResults() {
    generation++; clearTimeout(searchTimer); searchTimer = null; clearTimeout(detailTimer);
    activeWidget = null; selected = ''; detailRequest = null; fetched = null;
    restaurants.clear(); if (layer) layer.clearLayers();
    el('places-results').replaceChildren(); el('places-details').replaceChildren();
    el('result-count').textContent = 'Awaiting search'; el('selected-distance').textContent = '';
    el('detail-status').textContent = 'Select a restaurant card or numbered map marker.';
    button();
  }
  function expire() {
    if (!expired()) return false;
    clearResults(); status('Results have expired. Search again for current information.'); return true;
  }
  function icon(kind, active, label) {
    const node = document.createElement('div');
    node.className = 'map-pin ' + kind + (active ? ' active' : ''); node.textContent = label;
    return L.divIcon({className:'osm-marker', html:node, iconSize:[26,26], iconAnchor:[13,13]});
  }
  function renderScene(next) {
    const changed = !scene || scene.key !== next.key;
    scene = next;
    el('results-order').textContent = 'Up to 10 results · nearest distance';
    if (changed) {
      clearResults();
      status(ready ? (scene.landmark ? 'Ready to search this area.' : 'Choose a landmark to start exploring.') :
        'Map ready. Restaurant search is still connecting or needs configuration.');
    }
    if (!map) return;
    for (const [id, marker] of landmarks) {
      const active = scene.landmark?.landmark_id === id;
      marker.setIcon(icon('landmark', active, '◆')); marker.setZIndexOffset(active ? 300 : 0);
    }
    if (scene.landmark) {
      circle.setLatLng([scene.landmark.latitude, scene.landmark.longitude]).setRadius(scene.radius);
      if (!map.hasLayer(circle)) circle.addTo(map);
      if (changed) map.fitBounds(circle.getBounds(), {padding:[28,28]});
    } else {
      if (map.hasLayer(circle)) map.removeLayer(circle);
      if (changed && bounds.isValid()) map.fitBounds(bounds, {padding:[24,24]});
    }
    button();
  }
  function distance(place) {
    const a = L.latLng(scene.landmark.latitude, scene.landmark.longitude);
    return Math.round(a.distanceTo([place.location.lat(), place.location.lng()]));
  }
  function choose(place) {
    if (expire() || !place?.id || !restaurants.has(place.id) || selected === place.id) return;
    if (detailCalls >= limit * 2) { el('detail-status').textContent = 'Session detail limit reached. Existing results remain available.'; return; }
    detailCalls++; selected = place.id; clearTimeout(detailTimer);
    const version = generation;
    for (const [id, item] of restaurants) {
      item.marker.setIcon(icon('restaurant', id === selected, String(item.number)));
      item.marker.setZIndexOffset(id === selected ? 1000 : 500);
    }
    const item = restaurants.get(selected);
    map.panTo(item.marker.getLatLng());
    el('selected-distance').textContent = distance(item.place) + ' m from landmark · straight line';
    el('detail-status').textContent = 'Loading restaurant details…';
    // New element per selection makes stale events easy to discard.
    const widget = document.createElement('gmp-place-details');
    const request = document.createElement('gmp-place-details-place-request');
    request.place = item.place; detailRequest = request;
    widget.append(request, document.createElement('gmp-place-all-content'));
    const current = () => version === generation && detailRequest === request;
    widget.addEventListener('gmp-load', () => {
      if (!current()) return;
      clearTimeout(detailTimer); el('detail-status').textContent = 'Google restaurant details · hours and availability may change.';
    });
    const failure = () => {
      if (!current()) return;
      clearTimeout(detailTimer); el('places-details').replaceChildren(); selected = '';
      el('detail-status').textContent = 'Details could not load. Select a restaurant to retry; another request may be billed.';
    };
    widget.addEventListener('gmp-error', failure);
    detailTimer = setTimeout(failure, 25000);
    el('places-details').replaceChildren(widget);
  }
  function search(query) {
    if (!ready || !map || query.key !== scene?.key || searchCalls >= limit) return;
    searchCalls++; clearResults();
    const version = generation;
    const widget = document.createElement('gmp-place-search'); activeWidget = widget;
    widget.selectable = true;
    const request = document.createElement('gmp-place-nearby-search-request');
    request.includedPrimaryTypes = [query.cuisine || 'restaurant'];
    request.maxResultCount = 10; request.rankPreference = 'DISTANCE';
    request.locationRestriction = {center:{lat:query.landmark.latitude, lng:query.landmark.longitude}, radius:query.radius};
    widget.append(document.createElement('gmp-place-all-content'), request);
    const current = () => version === generation && activeWidget === widget;
    const failure = () => {
      if (!current()) return;
      clearResults(); status('Restaurant search failed. Check Places UI Kit API, billing, website restrictions and your connection. No automatic retry was made.', true);
    };
    widget.addEventListener('gmp-error', failure);
    widget.addEventListener('gmp-select', event => { if (current()) choose(event.place); });
    widget.addEventListener('gmp-load', () => {
      if (!current()) return;
      clearTimeout(searchTimer); searchTimer = null;
      layer.clearLayers(); restaurants.clear();
      const places = widget.places || [];
      places.forEach((place, i) => {
        if (!place.id || !place.location) return;
        const marker = L.marker([place.location.lat(), place.location.lng()], {
          icon:icon('restaurant', false, String(i + 1)), title:'Restaurant ' + (i + 1), zIndexOffset:500
        }).addTo(layer);
        marker.on('click', () => choose(place));
        restaurants.set(place.id, {marker, place, number:i + 1});
      });
      fetched = new Date(); el('result-count').textContent = places.length + ' results';
      status(places.length ? places.length + ' restaurants returned · nearest distance first. Select a card or numbered marker.' :
        'No restaurants returned. Try a different radius or cuisine.');
      button();
    });
    status('Searching nearby restaurants…');
    searchTimer = setTimeout(failure, 25000); button();
    el('places-results').replaceChildren(widget);
  }
  function googleFailure(message) {
    failed = true; ready = false; clearTimeout(loadTimer); clearResults();
    send('places_status', 'error'); status(message, true); button();
  }
  function init(config) {
    if (initialized) return; initialized = true; limit = Math.max(1, Number(config.requestLimit) || 15);
    if (!window.L) {
      el('map-message').querySelector('h3').textContent = 'OpenStreetMap could not load';
      el('map-message').querySelector('p').textContent = 'Check your internet connection and reload.';
      status('Leaflet map library unavailable.', true); return;
    }
    map = L.map('osm-map').setView([-37.8136,144.9631], 14);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom:19,
      attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map).on('tileerror', () => status('Some OpenStreetMap tiles could not load. Check your connection.', true));
    bounds = L.latLngBounds([]); layer = L.layerGroup().addTo(map);
    circle = L.circle([-37.8136,144.9631], {radius:600,color:'#087f75',weight:2,fillOpacity:0.08,interactive:false});
    for (const lm of config.landmarks) {
      const point = [lm.latitude, lm.longitude]; bounds.extend(point);
      const marker = L.marker(point, {icon:icon('landmark',false,'◆'),title:lm.landmark_name}).addTo(map);
      marker.on('click', () => { clearResults(); send('map_landmark',lm.landmark_id); });
      landmarks.set(lm.landmark_id, marker);
    }
    if (bounds.isValid()) map.fitBounds(bounds,{padding:[24,24]});
    el('map-message').hidden = true;
    if (scene) renderScene(scene);
    setInterval(expire, 30000);
    document.addEventListener('visibilitychange', expire);
    if (!config.browserKey) {
      send('places_status','not configured'); status('OpenStreetMap is ready. Add the browser key to .Renviron for restaurant search.',true); return;
    }
    send('places_status','loading');
    window.gm_authFailure = () => googleFailure('Google rejected the browser key. Check enabled APIs, billing and website restrictions. OpenStreetMap remains available.');
    window.explorerPlacesReady = async () => {
      try {
        if (failed) return;
        const lib = await window.google.maps.importLibrary('places');
        if (failed) return;
        if (!lib.PlaceSearchElement || !lib.PlaceDetailsElement) throw new Error('Unavailable UI Kit');
        clearTimeout(loadTimer); ready = true; send('places_status','ready');
        status(scene?.landmark ? 'Ready to search this area.' : 'Choose a landmark to start exploring.'); button();
      } catch (_) { googleFailure('Places UI Kit could not initialize. Check your connection and enabled APIs.'); }
    };
    loadTimer = setTimeout(() => googleFailure('Restaurant search timed out while connecting. Reload to try again; OpenStreetMap remains available.'),25000);
    const script = document.createElement('script');
    script.src = 'https://maps.googleapis.com/maps/api/js?' + new URLSearchParams({key:config.browserKey,v:'weekly',libraries:'places',
      callback:'explorerPlacesReady',loading:'async',language:'en',region:'AU'});
    script.async = true; script.onerror = () => googleFailure('Google library could not load. Check your connection.');
    document.head.appendChild(script);
  }
  function register() {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function' ||
        typeof window.Shiny.addCustomMessageHandler !== 'function' || typeof window.jQuery !== 'function') {
      setTimeout(register,50); return;
    }
    Shiny.addCustomMessageHandler('osm-init',init);
    Shiny.addCustomMessageHandler('osm-scene',renderScene);
    Shiny.addCustomMessageHandler('osm-search',search);
    Shiny.addCustomMessageHandler('osm-notice',message => status(message.text,true));
    // Clear promptly even before the server round trip; no automatic billable search.
    window.jQuery(document).on('change', '#landmark, #cuisine, #radius', () => {
      clearResults(); el('search').disabled = true; status('Updating search area…');
    });
    window.jQuery(document).on('shiny:disconnected', () => {
      ready = false; clearResults(); status('Connection to R was lost. Restart the app or reload.',true);
    });
    window.jQuery(document).on('shiny:connected', () => send('client_ready',Date.now()));
    send('client_ready',Date.now());
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',register); else register();
})();
