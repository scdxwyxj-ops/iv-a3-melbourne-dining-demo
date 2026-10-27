(() => {
  'use strict';
  const root = document.querySelector('.route-page');
  if (!root) return;
  const namespace = root.dataset.namespace;
  function activate(event) {
    const edit = event.target.closest('[data-route-edit]');
    if (edit) {
      Shiny.setInputValue(
        namespace + 'edit_stop',
        { action: edit.dataset.routeEdit, index: Number(edit.dataset.index) },
        { priority: 'event' },
      );
      return;
    }
    const choice = event.target.closest('[data-route-select]');
    if (choice)
      Shiny.setInputValue(namespace + 'select_venue', choice.dataset.routeSelect, {
        priority: 'event',
      });
  }
  root.addEventListener('click', activate);
  root.addEventListener('keydown', (event) => {
    if (!event.target.matches('.route-chart-point')) return;
    if (['Enter', ' '].includes(event.key)) {
      event.preventDefault();
      activate(event);
      return;
    }
    if (['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
      event.preventDefault();
      const points = [...root.querySelectorAll('.route-chart-point')],
        index = points.indexOf(event.target);
      const next =
        event.key === 'Home'
          ? 0
          : event.key === 'End'
            ? points.length - 1
            : Math.max(
                0,
                Math.min(points.length - 1, index + (event.key === 'ArrowLeft' ? -1 : 1)),
              );
      points.forEach((point, i) => point.setAttribute('tabindex', i === next ? '0' : '-1'));
      points[next]?.focus();
    }
  });
})();
