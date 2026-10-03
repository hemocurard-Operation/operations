const CACHE='hemocura-shell-v0.3.0';
const SHELL=['./','./index.html','./login.html','./css/app.css'];
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)))});
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const k of await caches.keys())if(k!==CACHE)await caches.delete(k);await self.clients.claim()})()));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;if(e.request.destination==='script')return;e.respondWith(fetch(e.request).catch(()=>caches.match(e.request)))});
