import { routeList, getRoute, getRouteMeta, navigate } from './router.js';
import { renderView } from './views.js';
import { mountDashboard } from './dashboard.js';
import { mountSales } from './sales.js';
import { mountDispatches } from './dispatch.js';
import { signOut } from './auth.js';

export function mountLayout(session){
  const app=document.getElementById('app');
  const navItems=routeList().map(([key,meta])=>`
    <button data-route="${key}">${meta.title}</button>`).join('');

  app.innerHTML=`
    <div class="app-layout">
      <aside class="sidebar" id="sidebar">
        <div class="sidebar-brand">
          <div class="brand-mark">H</div>
          <div><strong>HemoCura</strong><br><small>Operations v0.6.0</small></div>
        </div>
        <nav class="nav">${navItems}</nav>
      </aside>
      <section class="main-shell">
        <header class="topbar">
          <div>
            <button class="mobile-toggle secondary" id="menu-btn">☰</button>
            <strong id="page-title">Dashboard</strong>
            <div class="muted" id="page-subtitle"></div>
          </div>
          <div class="topbar-actions">
            <span class="muted">${session.user?.email || 'Usuario'}</span>
            <button id="logout-btn">Salir</button>
          </div>
        </header>
        <main class="content"><div id="view"></div></main>
      </section>
    </div>`;

  document.querySelectorAll('[data-route]').forEach(btn=>{
    btn.addEventListener('click',()=>navigate(btn.dataset.route));
  });

  document.getElementById('logout-btn').addEventListener('click',async()=>{
    await signOut();
    location.replace('./login.html');
  });

  document.getElementById('menu-btn')?.addEventListener('click',()=>{
    document.getElementById('sidebar').classList.toggle('open');
  });

  const render=async()=>{
    const route=getRoute();
    const meta=getRouteMeta(route);

    document.getElementById('page-title').textContent=meta.title;
    document.getElementById('page-subtitle').textContent=meta.subtitle;
    document.getElementById('view').innerHTML=renderView(route);

    document.querySelectorAll('[data-route]').forEach(btn=>{
      btn.classList.toggle('active',btn.dataset.route===route);
    });

    document.getElementById('sidebar').classList.remove('open');
    console.info('[HEMOCURA_ROUTER]',route);

    if(route==='dashboard') await mountDashboard(document.getElementById('dashboard-root'));
    if(route==='sales') await mountSales(document.getElementById('sales-root'));
    if(route==='dispatches') await mountDispatches(document.getElementById('dispatch-root'));
  };

  window.addEventListener('hashchange',()=>render().catch(error=>{
    console.error('[HEMOCURA_NAV_ERROR]',error);
  }));

  render().catch(error=>console.error('[HEMOCURA_NAV_ERROR]',error));
}
