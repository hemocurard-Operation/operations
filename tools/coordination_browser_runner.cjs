const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[path.join(__dirname,'../tests/wave50')]}));
(async()=>{
 const root=path.resolve(__dirname,'..'),out=process.env.HEMOCURA_COORD_BROWSER||'/tmp/hemocura-coordination-browser';fs.mkdirSync(out,{recursive:true});
 const server=http.createServer((req,res)=>{const p=new URL(req.url,'http://fixture.invalid').pathname,file=path.resolve(root,'.'+p);if(!file.startsWith(root+'/')||!['/hemocura-core/','/tests/','/css/','/VERSION.json'].some(x=>p.startsWith(x))){res.writeHead(403);return res.end()}fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);return res.end()}res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'text/html');res.end(data)})});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;let browser;const checks=[],errors=[];
 const check=(name,ok)=>{assert(ok,name);checks.push(name);console.log('PASS '+name)};
 try{
  browser=await chromium.launch({executablePath:fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':undefined,args:['--no-sandbox','--disable-dev-shm-usage']});const page=await browser.newPage({viewport:{width:1440,height:1000}});page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/*',route=>route.request().url().startsWith(origin)?route.continue():route.abort());
  await page.route('**/hemocura-core/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:fs.readFileSync(path.join(root,'tests/workflow/supabase-fixture.js'),'utf8')}));
  await page.goto(origin+'/tests/donors/browser.html');await page.waitForFunction(()=>window.donorReady);
  await page.evaluate(async()=>{
   const {localDay,rdTimestamp}=await import('/hemocura-core/workflow-domain.js'),{plusDays}=await import('/hemocura-core/coordination-domain.js');
   window.fixture.permissions=['DONORS_VIEW','DONORS_WRITE','SCREENING_WRITE','DONOR_AGENDA_CONFIG','ORDER_PLAN_VIEW','ORDER_PLAN_WRITE','WORKFLOW_VIEW'];
   const now=Date.now();window.fixture.tables.donor_contacts=[{id:'c1',donor_id:'d1',branch_id:'b1',outcome:'VOLVER_A_LLAMAR',contacted_at:new Date(now-3*86400000).toISOString(),next_contact_at:new Date(now-86400000).toISOString(),notes:'Volver a llamar'},{id:'c2',donor_id:'d2',branch_id:'b1',outcome:'NO_DESEA',contacted_at:new Date(now-86400000).toISOString(),notes:'No desea donar'}];
   window.fixture.tables.operations_orders=[{id:'o1',branch_id:'b1',reference:'VENCIDO-1',requester:'<img src=x onerror="window.evil=1">',component:'PG',units:3,due_at:new Date(now-86400000).toISOString(),responsible:'Equipo A',status:'PENDIENTE',priority:'URGENTE',revision:1}];
   window.fixture.tables.donor_agenda_capacity=[{branch_id:'b1',slot_minutes:30,capacity:3}];
   window.testVisit=rdTimestamp(plusDays(localDay(),2)+'T09:00');await window.remount();
   const {resetAccessCache}=await import('/hemocura-core/access-control.js');resetAccessCache();const div=document.createElement('div');div.id='operations-test';document.querySelector('#root').append(div);await (await import('/hemocura-core/workflow.js')).mountWorkflow(div);
  });
  await page.waitForSelector('[data-order-edit]');await page.waitForSelector('[data-capacity-form]',{state:'attached'});
  check('followup queue identifies overdue contacts',(await page.locator('[data-contact-table]').innerText()).includes('Seguimiento pendiente'));
  const initialWrites=await page.evaluate(()=>window.fixture.writes.length);
  await page.locator('[name=contact_state]').selectOption('PAUSADO');check('declined donor has no message action',await page.locator('[data-contact-table] [data-donor-message]').count()===0);
  await page.locator('[name=contact_state]').selectOption('PENDIENTES');await page.locator('[data-donor-message]').first().click();check('message contains no donor identity number',!(await page.locator('[data-message-text]').inputValue()).includes('00000000000'));
  check('WhatsApp opens only through a reviewed user action',(await page.locator('[data-message-whatsapp]').getAttribute('href')).startsWith('https://wa.me/18095550100?text='));
  check('preparing message never records contact',await page.evaluate(n=>window.fixture.writes.length===n,initialWrites));await page.locator('[data-message-close]').click();
  await page.evaluate(()=>window.fixture.tables.donor_contacts.push({id:'late-decline',donor_id:'d1',branch_id:'b1',outcome:'NO_DESEA',contacted_at:new Date().toISOString(),notes:'Declinó después de cargar la lista'}));
  await page.locator('[data-donor-message]').first().click();await page.waitForSelector('[data-communication-notice]');check('latest declined result blocks a stale message action',!(await page.locator('[data-message-dialog]').evaluate(d=>d.open))&&(await page.locator('[data-communication-notice]').innerText()).includes('no desea donar'));
  await page.evaluate(()=>window.fixture.tables.donor_contacts.pop());
  await page.evaluate(async()=>{window.fixture.tables.donor_visits=[{id:'v1',donor_id:'d1',branch_id:'b1',starts_at:window.testVisit,status:'CONFIRMADA',revision:1}];await window.remount()});await page.waitForSelector('[data-visit-message]');
  check('calendar includes existing appointment',(await page.locator('[data-calendar-table]').innerText()).includes('Confirmada'));
  await page.locator('[data-visit-message]').click();check('reminder contains exact RD appointment time',(await page.locator('[data-message-text]').inputValue()).includes('09:00'));await page.locator('[data-message-close]').click();
  await page.locator('summary').filter({hasText:'Configurar cupos'}).click();const cap=page.locator('[data-capacity-form]');await cap.locator('[name=branch_id]').selectOption('b1');await cap.locator('[name=capacity]').fill('2');await cap.locator('button').click();await page.waitForFunction(()=>window.fixture.tables.donor_agenda_capacity[0].capacity===2);check('capacity configuration persists actual chosen limit',true);
  // Remounting donors replaces only its own subtree; attach the operational planner again.
  await page.evaluate(async()=>{const div=document.createElement('div');div.id='operations-test';document.querySelector('#root').append(div);await (await import('/hemocura-core/workflow.js')).mountWorkflow(div)});
  check('order data is escaped',await page.locator('[data-order-table] img').count()===0&&await page.evaluate(()=>!window.evil));
  check('overdue urgent order is highlighted',(await page.locator('[data-order-table]').innerText()).includes('Vencido'));
  await page.locator('[data-order-new]').click();const form=page.locator('[data-order-form]');for(const [k,v] of Object.entries({reference:'PEDIDO-2',requester:'Centro sintético',component:'Plasma',units:'2',responsible:'Equipo B'}))await form.locator(`[name=${k}]`).fill(v);await form.locator('[name=branch_id]').selectOption('b1');await form.locator('[type=submit]').click();await page.waitForFunction(()=>window.fixture.tables.operations_orders.length===2);
  check('new order is administrative pending work',await page.evaluate(()=>window.fixture.tables.operations_orders.at(-1).status==='PENDIENTE'&&window.fixture.tables.operations_orders.at(-1).units===2));
  await page.waitForFunction(()=>!document.querySelector('[data-order-dialog]').open);await page.locator('[data-order-table] tr').filter({hasText:'PEDIDO-2'}).locator('button').click();await form.locator('[name=status]').selectOption('EN_GESTION');await form.locator('[type=submit]').click();await page.waitForFunction(()=>window.fixture.tables.operations_orders.at(-1).status==='EN_GESTION');check('order can move to managed state',true);
  check('orders do not generate donations or inventory writes',await page.evaluate(()=>window.fixture.writes.every(w=>!['donations','blood_inventory_units','inventory_movements'].includes(w.table))));
  await page.setViewportSize({width:390,height:844});check('planning and calendar fit mobile viewport',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(out,'coordination-mobile.png'),fullPage:true});
  await page.evaluate(async()=>{window.fixture.permissions=['DONORS_VIEW','ORDER_PLAN_VIEW','WORKFLOW_VIEW'];await window.remount();const div=document.createElement('div');document.querySelector('#root').append(div);await (await import('/hemocura-core/workflow.js')).mountWorkflow(div)});
  check('read-only users have no order contact or capacity write controls',await page.locator('[data-order-new],[data-donor-message],[data-capacity-form]').count()===0);
  check('no browser runtime errors',errors.length===0);
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({status:'PASS',checks,errors,production_verified:false},null,2));console.log(`${checks.length}/${checks.length} coordination browser checks passed`);
 }finally{await browser?.close();await new Promise(r=>server.close(r))}
})().catch(e=>{console.error(e);process.exitCode=1});
