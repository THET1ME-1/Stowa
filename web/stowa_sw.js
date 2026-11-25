// Service worker Stowa: кнопки уведомлений и уведомления с сервера, пока вкладка закрыта.
// Запросов страницы он не трогает — обработчика fetch нет, сайт грузится как раньше.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// Касание или кнопка: действие выполняет вкладка, которая держит хранилище (ответит «taken»).
// Такой нет — открыть Stowa, она выполнит действие из адреса при запуске.
self.addEventListener('notificationclick', (event) => {
  const notification = event.notification;
  notification.close();
  const data = notification.data || {};
  const message = { type: 'stowa-notification', action: event.action || 'open', payload: data.payload || '' };
  event.waitUntil(deliver(message));
});

async function deliver(message) {
  const tabs = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
  const own = tabs.filter((tab) => new URL(tab.url).origin === self.location.origin);
  let taken = null;
  try {
    taken = await Promise.any(own.map((tab) => ask(tab, message)));
  } catch (_) {
    taken = null;
  }
  if (taken) {
    if (message.action === 'open' && 'focus' in taken) await taken.focus();
    return;
  }
  await self.clients.openWindow('/?notification=' + encodeURIComponent(JSON.stringify(message)));
}

function ask(tab, message) {
  return new Promise((resolve, reject) => {
    const channel = new MessageChannel();
    const timer = setTimeout(() => reject(new Error('no answer')), 1500);
    channel.port1.onmessage = () => {
      clearTimeout(timer);
      resolve(tab);
    };
    tab.postMessage(message, [channel.port2]);
  });
}

// Уведомление с сервера, когда вкладка закрыта: текст зашифровала сама страница ключами
// этой подписки, сервер его не видит. Вкладка открыта и держит хранилище — она покажет сама.
self.addEventListener('push', (event) => {
  if (!event.data) return;
  let notice;
  try {
    notice = event.data.json();
  } catch (_) {
    return;
  }
  event.waitUntil(showPushed(notice));
});

async function showPushed(notice) {
  const tabs = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
  const visible = tabs.some((tab) => tab.visibilityState === 'visible' && new URL(tab.url).origin === self.location.origin);
  // браузер требует показать уведомление на каждый push; открытая вкладка уже показала своё
  // с тем же тегом — новое просто заменит его
  const actions = (notice.actions || []).map((one) => ({ action: one[0], title: one[1] }));
  await self.registration.showNotification(notice.title || 'Stowa', {
    body: notice.body || '',
    tag: notice.tag,
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    silent: !!notice.silent || visible,
    requireInteraction: !!notice.requireInteraction,
    data: { payload: notice.payload || '', tag: notice.tag },
    actions,
  });
}
