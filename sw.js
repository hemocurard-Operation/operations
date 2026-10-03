// HemoCura v0.14.0 RC-FREEZE
// Service Worker intentionally inert during stabilization.
// No fetch interception, no cache population.
self.addEventListener('install', event => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
