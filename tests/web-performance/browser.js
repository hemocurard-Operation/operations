import {fixture} from '../../hemocura-core/supabase.js';
import {mountLayout} from '../../hemocura-core/layout.js';
fixture.permissions=['DONORS_VIEW','DONORS_WRITE','SCREENING_WRITE'];
fixture.context={user_id:'demo',roles:['ATENCION_DONANTE'],full_name:'Operador ficticio',email:'test@example.invalid'};
fixture.tables.branches=[{id:'b',name:'Sucursal ficticia',active:true}];
fixture.tables.donors=Array.from({length:62},(_,i)=>({id:'d'+(i+1),donor_code:'DON-'+String(i+1).padStart(3,'0'),branch_id:'b',full_name:'Donante '+String(i+1).padStart(3,'0'),cedula:String(i+1).padStart(11,'0'),abo:'O',rh:'POSITIVO',registration_date:'2026-11-01',last_donation_date:'2026-01-01',next_donation_date:'2026-03-26',agenda_state:'FECHA_ALCANZADA'}));
fixture.tables.vw_donor_next_donation=fixture.tables.donors;
fixture.reads=[];fixture.readHook=q=>{fixture.reads.push({table:q.table,columns:q.columns,conditions:q.conditions});return undefined};
window.fixture=fixture;location.hash='#donors';await mountLayout({user:{id:'demo',email:'test@example.invalid'}});window.performanceReady=true;
