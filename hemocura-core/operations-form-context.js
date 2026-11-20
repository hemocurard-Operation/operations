import {roleCodes} from './role-labels.js';
export function assignedBranches(branches,access){
 if(roleCodes(access.context||{}).includes('SUPER_USUARIO'))return branches;
 const id=access.context?.profile_branch_id||access.context?.branch_id;
 return id?branches.filter(b=>b.id===id):[];
}
export function defaultDepartment(context){const roles=roleCodes(context||{});return roles.some(r=>['ENCARGADA_LABORATORIO','LABORATORIO','MEDICO_GERENTE_TECNICO'].includes(r))?'Laboratorio':roles.some(r=>r.startsWith('LOGISTICA'))?'Logística':roles.some(r=>['ASISTENTE_COMERCIAL','COMERCIAL'].includes(r))?'Comercial':roles.includes('CALIDAD')?'Calidad':roles.some(r=>['ADMIN','SUPER_USUARIO'].includes(r))?'Administración':'Operaciones';}
export function simplifyBranchPicker(select,branches){if(!select||branches.length!==1)return;select.value=branches[0].id;select.disabled=true;select.closest('label').hidden=true;const p=document.createElement('p');p.className='muted';p.textContent='Sucursal: '+branches[0].name;select.closest('label').after(p);}
