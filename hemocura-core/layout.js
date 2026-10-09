import { routeList,getRoute,getRouteMeta,navigate,routeGroups } from './router.js';
import { renderView,viewRootId } from './views.js';
import { mountOpsDashboard } from './ops-dashboard.js';
import { mountCommandCenter } from './command-center.js';
import { mountAudit } from './audit.js';
import { mountReleaseGate } from './release-gate.js';
import { mountSecurity } from './security.js';
import { mountDiagnostics } from './diagnostics.js';
import { mountApprovals } from './approvals.js';
import { mountQmsGovernance } from './qms-governance.js';
import { mountInternalAudits } from './internal-audits.js';
import { mountCompetencies } from './competencies.js';
import { mountResources } from './resources.js';
import { mountAnalyticalQc } from './analytical-qc.js';
import { mountFinalRelease } from './final-release.js';
import { mountUat } from './uat.js';
import { mountIntegration } from './integration.js';
import { mountContinuity } from './continuity.js';
import { mountManagementReview } from './management-review.js';
import { mountColdChain } from './cold-chain.js';
import { mountHemovigilance } from './hemovigilance.js';
import { mountSuppliers } from './suppliers.js';
import { filterRoutes, canRoute } from './access-control.js';
import { mountOperationalSales } from './operational-sales.js';
import { mountDonors } from './donors.js';
import { mountScreening } from './screening.js';
import { mountBloodFlow } from './blood-flow.js';
import { mountProduction } from './production.js';
import { mountSupplyPlanning } from './supply-planning.js';
import { mountBloodInventory } from './blood-inventory.js';
import { mountDailyInventory } from './daily-inventory.js';
import { mountDispatches } from './dispatch.js';
import { mountInventory } from './inventory.js';
import { mountRequisitions } from './requisitions.js';
import { mountInspections } from './inspections.js';
import { mountPlanning } from './planning.js';
import { mountIncidentsQuick } from './incidents-quick.js';
import { mountQuality } from './quality.js';
import { mountDocuments } from './documents.js';
import { mountCompliance } from './compliance.js';
import { mountBI } from './bi.js';
import { mountProjects } from './projects.js';
import { mountSettings } from './settings.js';
import { mountQA } from './qa.js';
import { signOut } from './auth.js';

const MOUNTS={
  dashboard:mountOpsDashboard,command:mountCommandCenter,audit:mountAudit,releasegate:mountReleaseGate,security:mountSecurity,
  diagnostics:mountDiagnostics,approvals:mountApprovals,qmsgov:mountQmsGovernance,internalaudits:mountInternalAudits,
  competencies:mountCompetencies,resources:mountResources,analyticalqc:mountAnalyticalQc,release1:mountFinalRelease,
  uat:mountUat,integration:mountIntegration,continuity:mountContinuity,management:mountManagementReview,
  coldchain:mountColdChain,hemovigilance:mountHemovigilance,suppliers:mountSuppliers,sales:mountOperationalSales,
  donors:mountDonors,screening:mountScreening,bloodflow:mountBloodFlow,production:mountProduction,supply:mountSupplyPlanning,
  bloodinventory:mountBloodInventory,dailyinventory:mountDailyInventory,dispatches:mountDispatches,inventory:mountInventory,requisitions:mountRequisitions,
  inspections:mountInspections,planning:mountPlanning,incidents:mountIncidentsQuick,quality:mountQuality,documents:mountDocuments,compliance:mountCompliance,
  bi:mountBI,projects:mountProjects,settings:mountSettings,qa:mountQA
};

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function buildGroupedNav(entries){const byGroup=new Map(routeGroups().map(g=>[g,[]]));for(const entry of entries){const group=entry[1].group||'SISTEMA';if(!byGroup.has(group))byGroup.set(group,[]);byGroup.get(group).push(entry)}return [...byGroup.entries()].filter(([,items])=>items.length).map(([group,items])=>`<section class="nav-group"><div class="nav-group-label">${esc(group)}</div>${items.map(([key,meta])=>`<button data-route="${esc(key)}" title="${esc(meta.subtitle||meta.title)}">${esc(meta.title)}</button>`).join('')}</section>`).join('')}
function moduleError(route,error){console.error('[HEMOCURA_MODULE_ERROR]',route,error);return `<section class="card"><div class="status bad"><strong>No se pudo cargar el módulo ${esc(route)}.</strong><br>${esc(error?.message||String(error))}</div></section>`}
export function mountedRouteKeys(){return Object.keys(MOUNTS)}

export async function mountLayout(session){
  const app=document.getElementById('app');if(!app)throw new Error('#app no disponible');
  const allowedRoutes=await filterRoutes(routeList());const nav=buildGroupedNav(allowedRoutes);
  app.innerHTML=`<div class="app-layout"><aside class="sidebar" id="sidebar"><div class="sidebar-brand"><div class="brand-mark">H</div><div><strong>HemoCura</strong><br><small>Operaciones · Sangre · SGC</small></div></div><label class="nav-search">Buscar módulo<input id="module-search" type="search" placeholder="Ej.: donantes, calidad" autocomplete="off"></label><p id="nav-empty" class="muted" hidden>No hay módulos coincidentes.</p><nav class="nav">${nav}</nav></aside><section class="main-shell"><header class="topbar"><div><button class="mobile-toggle secondary" id="menu-btn" aria-label="Abrir menú">☰</button><strong id="page-title">Mi trabajo</strong><div class="muted" id="page-subtitle"></div></div><div class="topbar-actions"><span class="muted">${esc(session.user?.email||'Usuario')}</span><button id="logout-btn">Salir</button></div></header><main class="content"><div id="view"></div></main></section></div>`;
  document.querySelectorAll('[data-route]').forEach(b=>b.onclick=()=>navigate(b.dataset.route));
  document.getElementById('module-search').addEventListener('input',event=>{const normalize=value=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();const query=normalize(event.target.value.trim());let matches=0;document.querySelectorAll('.nav-group').forEach(group=>{let visible=0;group.querySelectorAll('[data-route]').forEach(button=>{const match=normalize(button.textContent+' '+button.title).includes(query);button.hidden=!match;if(match)visible++});group.hidden=!visible;matches+=visible});document.getElementById('nav-empty').hidden=matches>0});
  document.getElementById('logout-btn').onclick=async()=>{await signOut();location.replace('./login.html')};
  document.getElementById('menu-btn')?.addEventListener('click',()=>document.getElementById('sidebar')?.classList.toggle('open'));
  const render=async()=>{const route=getRoute(),meta=getRouteMeta(route),access=await canRoute(route);if(!access.allowed){document.getElementById('page-title').textContent='Acceso denegado';document.getElementById('page-subtitle').textContent=`Permiso requerido: ${access.permission}`;document.getElementById('view').innerHTML=`<section class="card"><div class="status bad"><strong>Acceso denegado.</strong><br>Permiso requerido: <code>${esc(access.permission)}</code></div></section>`;return}document.getElementById('page-title').textContent=meta.title;document.getElementById('page-subtitle').textContent=meta.subtitle;document.getElementById('view').innerHTML=renderView(route);document.querySelectorAll('[data-route]').forEach(b=>b.classList.toggle('active',b.dataset.route===route));document.getElementById('sidebar')?.classList.remove('open');const mount=MOUNTS[route],rootId=viewRootId(route),root=rootId?document.getElementById(rootId):null;if(!mount){document.getElementById('view').innerHTML=moduleError(route,new Error('No existe mount registrado para esta ruta'));return}if(!root){document.getElementById('view').innerHTML=moduleError(route,new Error(`Root no encontrado: ${rootId||'NULL'}`));return}try{await mount(root)}catch(error){document.getElementById('view').innerHTML=moduleError(route,error)}};
  window.addEventListener('hashchange',()=>render().catch(e=>console.error('[HEMOCURA_NAV_ERROR]',e)));
  await render();
}
