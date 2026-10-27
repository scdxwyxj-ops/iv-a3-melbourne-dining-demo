/* Shared Leaflet maps, semantic marker colours and geometry layers. */

(() => {
  'use strict';
  const palette = Object.freeze(window.DiningConfig.map.palette);
  for (const [name, color] of Object.entries(palette))
    document.documentElement.style.setProperty('--map-' + name, color);
  const provider = Object.freeze(window.DiningConfig.map.provider);
  const views = new Map(),
    queued = new Map();
  const text = (tag, content, className = '') => {
    const node = document.createElement(tag);
    node.textContent = content;
    node.className = className;
    return node;
  };
  const zOrder = (options) =>
    options.emphasis ? 2000 : options.selected ? 1000 : options.role === 'landmark' ? 0 : 500;

  function markerRole(options) {
    if (options.role === 'cluster' || options.count > 1) return 'cluster';
    return options.role || 'venue';
  }

  function markerTone(options, role) {
    if (options.colour_by === 'catchment' && role !== 'landmark') {
      const catchmentTones = { a: 'primary', b: 'secondary', shared: 'shared' };
      return catchmentTones[options.membership] || 'primary';
    }
    if (role === 'venue') return options.category_code === '4512' ? 'takeaway' : 'primary';
    if (role === 'cluster') return 'primary';
    return options.tone || 'landmark';
  }

  function icon(options = {}) {
    const role = markerRole(options);
    const label =
      options.label ?? (options.count > 1 ? String(options.count) : role === 'landmark' ? '◆' : '');
    const size = role === 'landmark' ? 24 : role === 'cluster' || String(label).length ? 22 : 12;
    const node = text('span', label, 'core-map-marker' + (options.selected ? ' is-selected' : ''));
    const tone = markerTone(options, role);
    node.dataset.role = role;
    node.dataset.category =
      role === 'cluster' ? 'aggregate' : options.category_code || 'unclassified';
    node.dataset.encoding = options.colour_by || 'category';
    if (options.membership) node.dataset.membership = options.membership;
    node.style.setProperty('--marker-color', palette[tone]);
    return L.divIcon({
      className: 'core-map-icon',
      html: node,
      iconSize: [size, size],
      iconAnchor: [size / 2, size / 2],
    });
  }

  function create(id, options = {}) {
    if (views.has(id)) return views.get(id);
    const node = document.getElementById(id);
    if (!node) throw new Error('Map container missing: ' + id);
    node.classList.add('core-map-adapter');
    const map = L.map(node, {
      scrollWheelZoom: false,
      zoomControl: false,
      maxZoom: provider.maxZoom,
    }).setView([-37.8136, 144.9631], 14);
    L.control.zoom({ position: 'bottomright' }).addTo(map);
    L.control.scale({ imperial: false, position: 'bottomleft' }).addTo(map);
    let failures = 0;
    const message = text(
      'div',
      'Street tile loading failed. Explore the venue markers and results list.',
      'core-map-message',
    );
    message.hidden = true;
    node.append(message);
    const tiles = L.tileLayer(provider.url, {
      maxZoom: provider.maxZoom,
      attribution: provider.attribution,
    }).addTo(map);
    tiles.on('loading', () => {
      failures = 0;
    });
    tiles.on('tileerror', () => {
      failures++;
      message.hidden = false;
      options.onTileError?.();
    });
    tiles.on('load', () => {
      if (!failures) {
        message.hidden = true;
        options.onTileLoad?.();
      }
    });
    const layers = new Map(),
      markers = new Map();
    const view = {
      id,
      map,
      tiles,
      scope: null,
      pendingFit: null,
      layer(name = 'data', cluster = false) {
        if (!layers.has(name)) {
          const layer = cluster
            ? L.markerClusterGroup({
                showCoverageOnHover: false,
                disableClusteringAtZoom: 18,
                iconCreateFunction: (group) =>
                  icon({ role: 'cluster', count: group.getChildCount() }),
              })
            : L.layerGroup();
          layer.addTo(map);
          layers.set(name, layer);
        }
        return layers.get(name);
      },
      clear(name = 'data') {
        layers.get(name)?.clearLayers();
        for (const [key, m] of markers) if (m.layer === name) markers.delete(key);
      },
      clearAll() {
        for (const name of layers.keys()) view.clear(name);
      },
      marker(options, click) {
        const marker = L.marker([options.latitude, options.longitude], {
          icon: icon(options),
          title: options.title || '',
          alt: options.title || 'Map point',
          keyboard: true,
          zIndexOffset: zOrder(options),
        });
        marker.addTo(view.layer(options.layer || 'data', options.cluster));
        if (options.id)
          markers.set(options.id, { marker, options, layer: options.layer || 'data' });
        if (options.title)
          marker.bindTooltip(text('span', options.title), {
            direction: options.permanentLabel ? 'right' : 'top',
            permanent: Boolean(options.permanentLabel),
            offset: options.permanentLabel ? [15, 0] : [0, 0],
            className: 'core-map-label',
          });
        if (click) marker.on('click', () => click(marker));
        return marker;
      },
      setIcon(marker, options) {
        marker.setIcon(icon(options));
        marker.setZIndexOffset(zOrder(options));
      },
      popup(marker, content) {
        return marker.bindPopup(content, { maxWidth: 300, minWidth: 235 });
      },
      circle(center, radius, options = {}) {
        return L.circle(center, {
          radius,
          color: palette[options.tone] || palette.primary,
          weight: 2.5,
          dashArray: '7 6',
          fillOpacity: 0.065,
          interactive: false,
        }).addTo(view.layer(options.layer || 'data'));
      },
      line(points, options = {}) {
        return L.polyline(points, {
          color: palette[options.tone] || palette.route,
          weight: options.dashed ? 2 : 4,
          dashArray: options.dashed ? '6 5' : null,
          opacity: 0.9,
          interactive: false,
        }).addTo(view.layer(options.layer || 'route-lines'));
      },
      corridor(data) {
        return L.geoJSON(data, {
          style: { color: palette.route, weight: 1, dashArray: '5 5', fillOpacity: 0.055 },
          interactive: false,
        }).addTo(view.layer('route-corridor'));
      },
      polygons(data, click) {
        return L.geoJSON(data, {
          style: (feature) => ({
            color: feature.properties.core_selected ? palette.primary : '#657970',
            weight: feature.properties.core_selected ? 3 : 1,
            fillColor: feature.properties.core_selected ? palette.primary : '#dce6e0',
            fillOpacity: feature.properties.core_selected ? 0.12 : 0.25,
          }),
          onEachFeature: (feature, layer) => {
            layer.bindTooltip(text('span', feature.properties.featurenam));
            if (click) layer.on('click', () => click(feature.properties.featurenam));
          },
        }).addTo(view.layer('boundaries'));
      },
      visible() {
        return node.clientWidth > 0 && node.clientHeight > 0;
      },
      fit(bounds, options = {}) {
        view.pendingFit = { bounds, options };
        if (!view.visible()) return;
        map.invalidateSize({ pan: false });
        map.fitBounds(bounds, { padding: [26, 26], maxZoom: 17, animate: false, ...options });
        view.pendingFit = null;
      },
      fitRadius(center, radius) {
        const circle = L.circle(center, { radius });
        view.fit(circle.getBounds());
      },
      resize() {
        if (!view.visible()) return;
        map.invalidateSize({ pan: false });
        if (view.pendingFit) view.fit(view.pendingFit.bounds, view.pendingFit.options);
      },
      select(id) {
        for (const [key, item] of markers)
          view.setIcon(item.marker, {
            ...item.options,
            selected: (item.options.memberIds || [key]).includes(id),
          });
        node
          .querySelectorAll('[data-core-venue-id]')
          .forEach((button) =>
            button.setAttribute('aria-pressed', String(button.dataset.coreVenueId === id)),
          );
      },

      render(scene) {
        if (view.scope !== scene.scope) {
          view.scope = scene.scope;
          view.clearAll();
          if (scene.corridor) view.corridor(scene.corridor);
          for (const line of scene.lines || []) view.line(line.points, line);
          if (scene.boundaries) view.polygons(scene.boundaries, (id) => input(id, 'shape'));
          for (const circle of scene.circles || [])
            view.circle([circle.latitude, circle.longitude], circle.radius, circle);
          const groups = new Map(),
            points = [];
          for (const item of scene.markers || []) {
            if (item.role !== 'venue' || item.cluster) {
              points.push([item]);
              continue;
            }
            const key = item.latitude + ',' + item.longitude;
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key).push(item);
          }
          points.push(...groups.values());
          for (const members of points) {
            const first = members[0];
            const item =
              members.length === 1
                ? first
                : {
                    ...first,
                    count: members.length,
                    memberIds: members.map((m) => m.id),
                    title: members.length + ' venues at this location',
                  };
            const marker = view.marker(item, () => {
              if (item.role !== 'landmark' && members.length === 1) {
                view.select(item.id);
                input(item.id, 'marker');
              }
            });
            if (members.length > 1) {
              const choices = document.createElement('div');
              choices.append(text('strong', item.title, 'core-popup-title'));
              for (const member of members) {
                const button = text('button', member.title, 'core-venue-choice');
                button.type = 'button';
                button.dataset.coreVenueId = member.id;
                button.title = member.address || member.title;
                button.addEventListener('click', () => {
                  view.select(member.id);
                  input(member.id, 'marker');
                });
                choices.append(button);
              }
              view.popup(marker, choices);
            }
            if (item.popup && members.length === 1) {
              const node = document.createElement('div');
              node.append(text('strong', item.title || '', 'core-popup-title'));
              for (const line of item.popup) node.append(text('p', line, 'core-popup-line'));
              view.popup(marker, node);
            }
          }
          if (scene.bounds) view.fit(scene.bounds);
        }
        view.select(scene.selected);
        view.clear('route-selection');
        for (const line of scene.selection_lines || [])
          view.line(line.points, { ...line, layer: 'route-selection' });
      },
    };
    function input(value, type) {
      window.Shiny?.setInputValue(id + '_' + type + '_click', { id: value }, { priority: 'event' });
    }
    new ResizeObserver(() => view.resize()).observe(node);
    views.set(id, view);
    return view;
  }
  function scan() {
    document.querySelectorAll('.core-map[data-core-map-mode="scene"]').forEach((node) => {
      const view = create(node.id);
      if (queued.has(node.id)) {
        view.render(queued.get(node.id));
        queued.delete(node.id);
      }
      window.Shiny?.setInputValue(node.id + '_ready', true, { priority: 'event' });
    });
  }
  function register() {
    if (
      typeof window.Shiny?.addCustomMessageHandler !== 'function' ||
      typeof window.Shiny?.setInputValue !== 'function' ||
      !window.jQuery
    ) {
      setTimeout(register, 30);
      return;
    }
    Shiny.addCustomMessageHandler('core-map-render', (scene) => {
      const view = views.get(scene.id);
      if (view) view.render(scene);
      else queued.set(scene.id, scene);
    });
    Shiny.addCustomMessageHandler('core-map-fit', (message) =>
      views.get(message.id)?.fit(message.bounds),
    );
    $(document).on('shiny:connected', scan);
    $(document).on('shown.bs.tab', () => {
      scan();
      for (const view of views.values()) view.resize();
    });
    scan();
  }
  window.DiningMaps = Object.freeze({
    palette,
    provider,
    create,
    icon,
    get: (id) => views.get(id),
    all: () => [...views.values()],
  });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', register);
  else register();
})();
