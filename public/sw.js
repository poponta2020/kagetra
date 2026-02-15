// 景虎 Service Worker - Web Push 通知受信
self.addEventListener('push', function(event) {
  var data = {title: '景虎', body: '新しい通知があります', url: '/top'};
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }
  var options = {
    body: data.body,
    icon: '/img/apple-touch-icon.png',
    badge: '/img/apple-touch-icon.png',
    data: {url: data.url || '/top'}
  };
  event.waitUntil(
    self.registration.showNotification(data.title || '景虎', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  var url = event.notification.data && event.notification.data.url || '/top';
  event.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true}).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.indexOf(url) !== -1 && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
