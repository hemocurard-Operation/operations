import assert from 'node:assert/strict';
import {monday,addDays,ruleWarnings,candidates,overlaps} from '../../hemocura-core/crm-planner-domain.js';
assert.equal(monday('2026-11-08'),'2026-11-02');assert.equal(addDays('2026-12-31',1),'2027-01-01');
const rule={contact_id:'a',slots:[{day:1,period:'AM'}],priority:'ALTA',needs_review:false,appointment_required:true};
assert.deepEqual(ruleWarnings(rule,'2026-11-09','09:00'),['Requiere cita previa']);assert(ruleWarnings(rule,'2026-11-10','09:00').includes('Fuera de los días o tandas registrados'));
const contacts=[{id:'a',full_name:'Prueba A',center:'Centro A',specialty:'Cardiología',stage:'PROSPECTO'},{id:'b',full_name:'Prueba B',stage:'ACTIVO',preferred_channel:'NO_CONTACTAR'}];
assert.equal(candidates(contacts,[rule],{specialty:'cardiologia',day:'1',period:'AM',rule:'CITA'}).length,1);assert.equal(candidates(contacts,[rule],{day:'2'}).length,0);assert.equal(candidates(contacts,[rule],{}).length,1);
assert(overlaps([{agent_id:'a',status:'PLANIFICADA',scheduled_at:'2026-11-09T13:00:00Z',duration_minutes:30}],'2026-11-09T13:15:00Z',30,'a'));assert(!overlaps([{agent_id:'a',status:'CANCELADA',scheduled_at:'2026-11-09T13:00:00Z',duration_minutes:30}],'2026-11-09T13:15:00Z',30,'a'));
console.log('PASS: calendario, filtros, reglas, exclusión no contactar y solapes');
