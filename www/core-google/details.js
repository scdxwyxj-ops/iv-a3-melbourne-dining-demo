/* Places UI Kit: page-level SDK and query state; modal-level requests and DOM. */

(() => {
  'use strict';
  const sessionsByElement = new WeakMap(),
    confirmedPlaceIds = new Map();
  let activeSession = null,
    sdkPromise = null,
    sdkStatus = 'not-loaded',
    pageQueryCount = 0;
  const SDK_TIMEOUT = window.DiningConfig.google.sdk_timeout_ms,
    QUERY_TIMEOUT = window.DiningConfig.google.query_timeout_ms;

  // Page lifetime: SDK promise, query count and confirmed Place IDs.
  // Modal lifetime: DOM references, current request version and timeout.
  // Flow: loading-sdk -> searching -> choose-match -> loading-details -> ready.
  // Error/empty/limit states require an explicit user action; close invalidates

  // Page state holds the SDK, query count and confirmed Place IDs.
  // Modal state holds DOM references, request revisions and timeout handles.
  // Flow: SDK loading -> search -> match confirmation -> details -> ready.
  const PHASE = Object.freeze({
    LOADING_SDK: 'loading-sdk',
    SEARCHING: 'searching',
    CHOOSE_MATCH: 'choose-match',
    LOADING_DETAILS: 'loading-details',
    READY: 'ready',
    ERROR: 'error',
    EMPTY: 'empty',
    LIMIT: 'limit',
    NOT_CONFIGURED: 'not-configured',
  });

  function isCurrentRequest(state, requestRevision = state.requestRevision) {
    return (
      activeSession === state &&
      !state.closed &&
      state.node.isConnected &&
      state.requestRevision === requestRevision
    );
  }
  function setStatus(state, message, code) {
    state.node.dataset.status = code;
    state.node.querySelector('.google-detail-status').textContent = message;
    state.node
      .querySelector('.google-detail-status')
      .setAttribute(
        'role',
        [PHASE.NOT_CONFIGURED, PHASE.ERROR, PHASE.EMPTY, PHASE.LIMIT].includes(code)
          ? 'alert'
          : 'status',
      );
  }
  function clearTimer(state) {
    clearTimeout(state.timer);
    state.timer = null;
  }
  function closeDetailsSession(state) {
    state.closed = true;
    state.requestRevision++;
    clearTimer(state);
    state.host.replaceChildren();
    if (activeSession === state) activeSession = null;
  }

  function loadSdk(key) {
    if (sdkPromise) return sdkPromise;
    sdkStatus = 'loading';
    sdkPromise = new Promise((resolve, reject) => {
      let finished = false;
      const timer = setTimeout(() => fail('sdk-timeout'), SDK_TIMEOUT);
      const fail = (code = 'sdk-unavailable') => {
        if (finished) return;
        finished = true;
        clearTimeout(timer);
        sdkStatus = PHASE.ERROR;
        const error = new Error('Google library loading failed');
        error.code = code;
        reject(error);
      };
      const ready = async () => {
        try {
          await window.google.maps.importLibrary('places');
          await Promise.all(
            [
              'gmp-place-search',
              'gmp-place-details',
              'gmp-place-text-search-request',
              'gmp-place-details-place-request',
            ].map((tag) => customElements.whenDefined(tag)),
          );
          if (finished) return;
          finished = true;
          clearTimeout(timer);
          sdkStatus = PHASE.READY;
          resolve();
        } catch (_) {
          fail();
        }
      };
      const previousFailure = window.gm_authFailure;
      window.gm_authFailure = () => {
        fail('auth-failed');
        if (
          finished &&
          sdkStatus === PHASE.READY &&
          activeSession &&
          isCurrentRequest(activeSession)
        ) {
          failure(
            activeSession,
            activeSession.requestRevision,
            activeSession.chosenId ? 'details' : 'search',
            activeSession.chosenId,
            'auth-failed',
          );
        }
        if (typeof previousFailure === 'function') previousFailure();
      };
      if (window.google?.maps?.importLibrary) {
        void ready();
        return;
      }
      window.ivGoogleDetailsReady = ready;
      const script = document.createElement('script');
      script.src =
        'https://maps.googleapis.com/maps/api/js?' +
        new URLSearchParams({
          key,
          v: 'weekly',
          libraries: 'places',
          callback: 'ivGoogleDetailsReady',
          loading: 'async',
          language: 'en',
          region: 'AU',
        });
      script.async = true;
      script.dataset.ivGoogleSdk = 'true';
      script.onerror = () => fail(navigator.onLine === false ? 'offline' : 'sdk-unavailable');
      document.head.append(script);
    });

    // action may try again after a transient network error.
    sdkPromise.catch(() => {
      sdkPromise = null;
    });
    return sdkPromise;
  }

  function allowance(state) {
    if (pageQueryCount < state.config.request_limit) return true;
    clearTimer(state);
    state.requestRevision++;
    state.retry.hidden = true;
    state.heading.hidden = true;
    state.host.replaceChildren();
    setStatus(
      state,
      'Google details loading failed. Reason: this page session has reached its live-query limit (' +
        state.config.request_limit +
        ' searches and detail queries).',
      PHASE.LIMIT,
    );
    return false;
  }

  function errorMessage(code, kind = 'details') {
    const reasons = {
      offline: 'your browser is offline.',
      'sdk-timeout': 'Google library loading exceeded 15 seconds.',
      'sdk-unavailable': 'the Google library connection failed.',
      'auth-failed':
        'Google rejected API authentication. Check the key and allowed website restrictions.',
      'query-timeout':
        'the Google ' +
        (kind === 'search' ? 'restaurant search' : 'details request') +
        ' exceeded 15 seconds.',
      'request-rejected':
        'the Google ' +
        (kind === 'search' ? 'restaurant search' : 'details request') +
        ' returned a request error.',
    };
    return (
      'Google details loading failed. Reason: ' +
      reasons[code in reasons ? code : 'request-rejected']
    );
  }

  function failure(state, requestRevision, retryKind, placeId, reason = 'request-rejected') {
    if (!isCurrentRequest(state, requestRevision)) return;
    clearTimer(state);
    state.requestRevision++;
    state.host.replaceChildren();
    state.heading.hidden = true;
    state.retryKind = retryKind;
    state.retryPlaceId = placeId;
    state.retry.hidden = false;
    setStatus(
      state,
      errorMessage(navigator.onLine === false ? 'offline' : reason, retryKind),
      PHASE.ERROR,
    );
  }

  function search(state) {
    if (!isCurrentRequest(state) || !allowance(state)) return;
    clearTimer(state);
    const requestRevision = ++state.requestRevision;
    state.chosenId = null;
    state.retry.hidden = true;
    state.heading.hidden = true;
    setStatus(
      state,
      'Finding Google listings by this restaurant’s name and address…',
      PHASE.SEARCHING,
    );
    const widget = document.createElement('gmp-place-search');
    widget.selectable = true;
    const request = document.createElement('gmp-place-text-search-request');
    request.textQuery = `${state.config.name}, ${state.config.address}`;
    request.locationBias = { lat: state.config.latitude, lng: state.config.longitude };
    request.maxResultCount = 3;
    // Search item content uses the documented template slot (different from
    // the Details element's direct children). Keep attribution outside it.
    const template = document.createElement('template');
    template.slot = 'details-item';
    template.content.append(
      ...['gmp-place-name', 'gmp-place-address', 'gmp-place-type'].map((tag) =>
        document.createElement(tag),
      ),
    );
    const attribution = document.createElement('gmp-place-attribution');
    attribution.setAttribute('light-scheme-color', 'gray');
    attribution.setAttribute('dark-scheme-color', 'white');
    widget.append(request, template, attribution);
    const fail = () => failure(state, requestRevision, 'search');
    widget.addEventListener('gmp-error', fail);
    widget.addEventListener('gmp-load', () => {
      if (!isCurrentRequest(state, requestRevision)) return;
      clearTimer(state);
      const places = widget.places || [];
      state.candidateIds = new Set(places.map((place) => place.id).filter(Boolean));
      state.heading.hidden = state.candidateIds.size === 0;
      setStatus(
        state,
        state.candidateIds.size
          ? 'Check the name and address, then select the correct Google listing below.'
          : 'Google details loading failed. Reason: the search returned 0 matching listings for this restaurant’s name and address.',
        state.candidateIds.size ? PHASE.CHOOSE_MATCH : PHASE.EMPTY,
      );
      state.retryKind = 'search';
      state.retry.hidden = state.candidateIds.size > 0;
    });
    widget.addEventListener('gmp-select', (event) => {
      if (
        !isCurrentRequest(state, requestRevision) ||
        !event.place?.id ||
        !state.candidateIds?.has(event.place.id)
      )
        return;

      confirmedPlaceIds.set(state.config.venue_id, event.place.id);
      details(state, event.place.id);
    });
    pageQueryCount++;
    state.timer = setTimeout(
      () => failure(state, requestRevision, 'search', undefined, 'query-timeout'),
      QUERY_TIMEOUT,
    );
    state.host.replaceChildren(widget);
  }

  function details(state, placeId) {
    if (
      !isCurrentRequest(state) ||
      (state.chosenId === placeId &&
        [PHASE.LOADING_DETAILS, PHASE.READY].includes(state.node.dataset.status))
    )
      return;
    if (!allowance(state)) return;
    clearTimer(state);
    const requestRevision = ++state.requestRevision;
    state.chosenId = placeId;
    state.heading.hidden = true;
    state.retry.hidden = true;
    setStatus(
      state,
      'Loading live Google details for the listing you selected…',
      PHASE.LOADING_DETAILS,
    );
    const widget = document.createElement('gmp-place-details');
    const request = document.createElement('gmp-place-details-place-request');
    request.place = placeId;
    widget.append(
      request,
      ...[
        'gmp-place-name',
        'gmp-place-address',
        'gmp-place-rating',
        'gmp-place-type',
        'gmp-place-price',
        'gmp-place-open-now-status',
        'gmp-place-opening-hours',
        'gmp-place-website',
        'gmp-place-phone-number',
        'gmp-place-reviews',
      ].map((tag) => document.createElement(tag)),
    );
    const fail = () => failure(state, requestRevision, 'details', placeId);
    widget.addEventListener('gmp-error', fail);
    widget.addEventListener('gmp-load', () => {
      if (!isCurrentRequest(state, requestRevision)) return;
      clearTimer(state);
      setStatus(
        state,
        'Live details from Google. Confirm that the displayed name and address match your restaurant.',
        PHASE.READY,
      );
    });
    pageQueryCount++;
    state.timer = setTimeout(
      () => failure(state, requestRevision, 'details', placeId, 'query-timeout'),
      QUERY_TIMEOUT,
    );
    state.host.replaceChildren(widget);
  }

  async function start(state) {
    if (!state.config.browser_key) {
      setStatus(
        state,
        'Google details loading failed. Reason: Google API key configuration is required.',
        PHASE.NOT_CONFIGURED,
      );
      return;
    }
    if (!allowance(state)) return;
    setStatus(state, 'Loading Google details on demand…', PHASE.LOADING_SDK);
    const requestRevision = state.requestRevision;
    try {
      await loadSdk(state.config.browser_key);
      if (!isCurrentRequest(state, requestRevision)) return;
      const id = confirmedPlaceIds.get(state.config.venue_id);
      if (id) details(state, id);
      else search(state);
    } catch (error) {
      if (!isCurrentRequest(state, requestRevision)) return;
      state.retryKind = 'sdk';
      state.retry.hidden = false;
      setStatus(
        state,
        errorMessage(navigator.onLine === false ? 'offline' : error.code || 'sdk-unavailable'),
        PHASE.ERROR,
      );
    }
  }

  function createDetailsSession(node, config) {
    return {
      node,
      config,
      closed: false,
      requestRevision: 0,
      host: node.querySelector('.google-place-host'),
      heading: node.querySelector('.google-match-heading'),
      retry: node.querySelector('.google-retry'),
    };
  }

  function registerRetryAction(state) {
    state.retry.addEventListener('click', () => {
      if (!isCurrentRequest(state)) return;
      state.retry.hidden = true;
      if (state.retryKind === 'details') {
        state.chosenId = null;
        details(state, state.retryPlaceId);
      } else if (state.retryKind === 'search') search(state);
      else void start(state);
    });
  }

  function scan() {
    if (activeSession && !activeSession.node.isConnected) closeDetailsSession(activeSession);
    document.querySelectorAll('#shiny-modal .google-venue-details').forEach((node) => {
      if (sessionsByElement.has(node)) return;
      if (activeSession) closeDetailsSession(activeSession);
      let config;
      try {
        config = JSON.parse(node.dataset.googleConfig);
      } catch (_) {
        sessionsByElement.set(node, null);
        node.dataset.status = PHASE.ERROR;
        const message = node.querySelector('.google-detail-status');
        message.textContent =
          'Google details loading failed. Reason: the details configuration is invalid.';
        message.setAttribute('role', 'alert');
        return;
      }
      const state = createDetailsSession(node, config);
      sessionsByElement.set(node, state);
      activeSession = state;
      registerRetryAction(state);
      void start(state);
    });
  }
  function initialise() {
    new MutationObserver(scan).observe(document.body, { childList: true, subtree: true });
    window.jQuery?.(document).on('hide.bs.modal', '#shiny-modal', (event) => {
      if (activeSession && event.currentTarget.contains(activeSession.node))
        closeDetailsSession(activeSession);
    });
    scan();
  }

  window.DiningGoogleDetails = Object.freeze({
    stats: () => ({
      sdk: sdkStatus,
      requests: pageQueryCount,
      confirmedMatches: confirmedPlaceIds.size,
    }),
  });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialise);
  else initialise();
})();
