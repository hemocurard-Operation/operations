// HemoCura v0.2.0
// Durante esta fase NO cacheamos módulos JS para evitar servir código viejo mientras depuramos.
const CACHE='hemocura-shell-v0.2.0';
const SHELL=['./','./index.html','./login.html','./css/app.css'];
self.addEventListener('install',e=>{ self.skipWaiting(); e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL))); });
self.addEventListener('activate',e=>e.waitUntil((async()=>{
  const keys=await caches.keys();
  await Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)));
  await self.clients.claim();
})()));
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET') return;
  if(e.request.destination==='script') return;
  e.respondWith(fetch(e.request).catch(()=>caches.match(e.request)));
});
