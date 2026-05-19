// Минимальный FFI для работы с URL hash

let debounceTimer = null;

export function setHash(hash) {
  window.location.hash = hash;

  // Дебаунсинг отправки в Яндекс Метрику (2 сек)
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    if (typeof ym !== 'undefined') {
      ym(106066101, 'hit', window.location.href);
      ym(106066101, 'reachGoal', 'inventory_changed');
    }
  }, 2000);
}
