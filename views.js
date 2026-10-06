const ROOT_IDS={
  "dashboard": "ops-dashboard-root",
  "command": "command-root",
  "audit": "audit-root",
  "releasegate": "releasegate-root",
  "security": "security-root",
  "diagnostics": "diagnostics-root",
  "approvals": "approvals-root",
  "qmsgov": "qmsgov-root",
  "internalaudits": "internalaudits-root",
  "competencies": "competencies-root",
  "resources": "resources-root",
  "analyticalqc": "analyticalqc-root",
  "release1": "release1-root",
  "uat": "uat-root",
  "integration": "integration-root",
  "continuity": "continuity-root",
  "management": "management-root",
  "coldchain": "coldchain-root",
  "hemovigilance": "hemovigilance-root",
  "suppliers": "suppliers-root",
  "sales": "sales-root",
  "donors": "donors-root",
  "screening": "screening-root",
  "bloodflow": "bloodflow-root",
  "production": "production-root",
  "supply": "supply-root",
  "bloodinventory": "bloodinventory-root",
  "dispatches": "dispatch-root",
  "inventory": "inventory-root",
  "requisitions": "requisitions-root",
  "inspections": "inspections-root",
  "planning": "planning-root",
  "quality": "quality-root",
  "documents": "documents-root",
  "compliance": "compliance-root",
  "bi": "bi-root",
  "projects": "projects-root",
  "settings": "settings-root",
  "qa": "qa-root"
};

export function viewRootId(route){
  return ROOT_IDS[route] || null;
}

export function renderView(route){
  const id=viewRootId(route);
  return id
    ? `<div id="${id}"></div>`
    : `<section class="card"><div class="status bad"><strong>Ruta sin vista registrada.</strong><br><code>${String(route||'')}</code></div></section>`;
}

export function registeredViewRoutes(){
  return Object.keys(ROOT_IDS);
}
