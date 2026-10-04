export function renderView(route){
 const ids={dashboard:'ops-dashboard-root',command:'command-root',audit:'audit-root',releasegate:'releasegate-root',security:'security-root',diagnostics:'diagnostics-root',approvals:'approvals-root',qmsgov:'qmsgov-root',sales:'sales-root',donors:'donors-root',screening:'screening-root',bloodflow:'bloodflow-root',production:'production-root',supply:'supply-root',bloodinventory:'bloodinventory-root',
 dispatches:'dispatch-root',inventory:'inventory-root',requisitions:'requisitions-root',inspections:'inspections-root',planning:'planning-root',
 quality:'quality-root',documents:'documents-root',compliance:'compliance-root',bi:'bi-root',projects:'projects-root',settings:'settings-root',qa:'qa-root'};
 return ids[route]?`<div id="${ids[route]}"></div>`:`<section class="card"><div class="status warn">Ruta no reconocida.</div></section>`;
}
