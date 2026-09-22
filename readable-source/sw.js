const CACHE_NAME = "jpp1e-trpg-stabilization-20260920";

const APP_SHELL = [
  "./",
  "./index.html",
  "./player-access.js",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key.startsWith("jpp1e-trpg-") && key !== CACHE_NAME)
          .map(key => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Never restore an old installation endpoint from Cache Storage.
  if(url.pathname===new URL('./config.js',self.location.href).pathname){
    event.respondWith(fetch(req,{cache:'no-store'}));
    return;
  }

  // Prefer the newly deployed page/assets, then fall back to the latest cache offline.
  const networkResponse = fetch(req, { cache: "no-store" });
  event.waitUntil(
    networkResponse.then(response => {
      if (response && response.ok) {
        const copy = response.clone();
        return caches.open(CACHE_NAME).then(cache => cache.put(req, copy));
      }
    }, () => {}).catch(err => console.warn("Jpp1e cache update failed:", err))
  );
  event.respondWith(
    networkResponse.catch(async () => {
      const cached = await caches.match(req);
      if (cached) return cached;
      if (req.mode === "navigate") {
        const page = await caches.match("./index.html");
        if (page) return page;
      }
      return Response.error();
    })
  );
});

self.addEventListener("push", event => {
  let data = {
    title: "Jpp1e TRPG",
    body: "새로운 메시지가 도착했습니다.",
    tag: "jpp1e",
    url: "./"
  };

  try {
    if (event.data) data = { ...data, ...event.data.json() };
  } catch (e) {}

  event.waitUntil((async () => {
    await self.registration.showNotification(data.title || "Jpp1e TRPG", {
      body: data.body || "새로운 메시지가 도착했습니다.",
      icon: "./icon-192.png",
      badge: "./icon-192.png",
      tag: data.tag || "jpp1e",
      renotify: true,
      data: { url: data.url || "./" }
    });
  })());
});

self.addEventListener("notificationclick", event => {
  event.notification.close();

  const target = event.notification.data?.url || "./";

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: "window",
      includeUncontrolled: true
    });

    for (const w of windows) {
      if ("focus" in w) {
        await w.focus();
        return;
      }
    }

    if (self.clients.openWindow) await self.clients.openWindow(target);
  })());
});
