const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[path.join(__dirname,'../tests/wave50')]}));
(async()=>{
 const root=path.resolve(__dirname,'..'),out=process.env.HEMOCURA_MODULE_BROWSER_REPORT||'/tmp/hemocura-module-views-browser';fs.mkdirSync(out,{recursive:true});
 const config=JSON.parse(fs.readFileSync(path.join(root,'contracts/role-task-access-defaults.json'),'utf8'));
 const server=http.createServer((req,res)=>{const p=new URL(req.url,'http://fixture.invalid').pathname,file=path.resolve(root,'.'+p);if(!file.startsWith(root+'/')||!['/hemocura-core/','/tests/','/css/','/VERSION.json'].some(x=>p.startsWith(x))){res.writeHead(403);return res.end()}fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);return res.end()}res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'text/html');res.end(data)})});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;let browser;const checks=[],errors=[];let failure;
 const check=(name,ok)=>{assert(ok,name);checks.push(name);console.log('PASS '+name)};
 try{
  browser=await chromium.launch({executablePath:process.env.HEMOCURA_BROWSER||(fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':undefined),args:['--no-sandbox','--disable-dev-shm-usage']});const page=await browser.newPage({viewport:{width:1440,height:1000}});page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>r.request().url().startsWith(origin)?r.continue():r.abort());await page.route('**/hemocura-core/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:fs.readFileSync(path.join(root,'tests/workflow/supabase-fixture.js'),'utf8')}));
  await page.goto(origin+'/tests/module-views/browser.html');await page.waitForFunction(()=>window.modulesReady);
  check('home prioritizes the operational donor workspace',await page.locator('[data-work-route]').first().getAttribute('data-work-route')==='donors');
  check('home hides financial laboratory and technical windows',await page.locator('[data-work-route=screening],[data-work-route=collections],[data-work-route=releasegate]').count()===0);
  check('enabled donor route is accepted',await page.evaluate(async()=>(await window.canRoute('donors')).allowed));
  check('disabled direct link is denied despite data permission',await page.evaluate(async()=>{const x=await window.canRoute('screening');return !x.allowed&&x.reason==='MODULE_DISABLED_FOR_ROLE'}));
  check('unknown routes fail closed',await page.evaluate(async()=>!(await window.canRoute('invented-module')).allowed));
  await page.evaluate(()=>{fixture.tables.vw_my_module_access.find(m=>m.route_key==='donors').enabled=false});check('module revocation is checked without resetting access cache',await page.evaluate(async()=>!(await window.canRoute('donors')).allowed));
  await page.evaluate(()=>{fixture.tables.vw_my_module_access.find(m=>m.route_key==='donors').enabled=true});
  await page.evaluate(async()=>window.mountWorkflow());check('operational map shows only enabled destinations',await page.locator('#workflow a[href="#donors"]').count()===1&&await page.locator('#workflow a[href="#bloodinventory"],#workflow a[href="#dailyinventory"]').count()===0);
  await page.evaluate(async()=>{fixture.permissions=['DONORS_VIEW'];await window.mountEditor()});check('non super user has no module editor',await page.locator('[data-module-role]').count()===0);
  await page.evaluate(async config=>{
   const codes=Object.keys(config.profiles);fixture.context={roles:['SUPER_USUARIO']};fixture.permissions=[...new Set(config.modules.map(m=>m.permission_code))];
   fixture.tables.roles=codes.map(code=>({id:code,code,name:code}));fixture.tables.app_module_catalog=config.modules;
   fixture.tables.role_module_access=codes.flatMap(role_id=>config.modules.map(m=>({role_id,route_key:m.route_key,enabled:config.profiles[role_id].includes(m.route_key),revision:1})));
   fixture.tables.role_permissions=codes.flatMap(role_id=>config.role_permissions[role_id].map(permission_code=>({role_id,permission_code})));
   fixture.tables.vw_my_module_access=config.modules.map(m=>({...m,enabled:true}));
   fixture.rpcHandler=async(name,args)=>{
    if(name==='set_role_modules'){
     if(fixture.saveGate)await fixture.saveGate;if(fixture.rejectSave)return {error:{message:'La configuración cambió. Actualice y vuelva a intentar.'}};
     for(const change of args.p_changes){const s=fixture.tables.role_module_access.find(x=>x.role_id===args.p_role&&x.route_key===change.route_key);s.enabled=change.enabled;s.revision++}
     return {data:{updated:args.p_changes.length}}
    }return {data:null,error:null}
   };await window.mountEditor();
  },config);
  check('configuration paginates beyond 500 role module records',await page.locator('[data-module-toggle]').count()===config.modules.length&&await page.locator('[data-module-role] option').count()===Object.keys(config.profiles).length);
  await page.locator('[data-module-role]').selectOption('SUPER_USUARIO');check('super user settings are locked on',await page.locator('[data-module-toggle]:enabled').count()===0&&await page.locator('[data-module-toggle]:checked').count()===config.modules.length);
  check('super has all registered routes',(await page.evaluate(async()=>(await window.filterRoutes()).length))===config.modules.length);
  await page.locator('[data-module-role]').selectOption('ASISTENTE_OPERACIONES');check('identity administration cannot be enabled for another role',await page.locator('[data-module-toggle=users]').isDisabled()&&await page.locator('[data-module-toggle=security]').isDisabled());
  const row=page.locator('[data-module-table] tr').filter({has:page.locator('[data-module-toggle=screening]')});check('editor distinguishes missing data permissions',(await row.innerText()).includes('Sin permiso de datos'));
  await page.locator('[data-module-toggle=donors]').uncheck();check('save includes only explicit pending changes',(await page.locator('[data-module-summary]').innerText()).includes('1 cambios pendientes'));
  await page.evaluate(()=>{fixture.rejectSave=true});await page.locator('[data-module-save]').click();await page.waitForFunction(()=>document.querySelector('[data-module-status]').textContent.includes('configuración cambió'));check('conflict preserves pending configuration',!await page.locator('[data-module-toggle=donors]').isChecked()&&await page.locator('[data-module-save]').isEnabled());
  await page.evaluate(()=>{fixture.rejectSave=false;fixture.saveGate=new Promise(r=>window.releaseSave=r)});await page.locator('[data-module-save]').click();check('save locks role and checkbox changes',await page.locator('[data-module-role]').isDisabled()&&await page.locator('[data-module-toggle=donors]').isDisabled());await page.evaluate(()=>{window.releaseSave();fixture.saveGate=null});await page.waitForFunction(()=>document.querySelector('[data-module-status]').textContent.includes('Configuración guardada'));check('module configuration persists successfully',await page.evaluate(()=>!fixture.tables.role_module_access.find(x=>x.role_id==='ASISTENTE_OPERACIONES'&&x.route_key==='donors').enabled));
  check('configuration never modifies data permission assignments',await page.evaluate(()=>fixture.writes.length===0&&fixture.rpcCalls.filter(c=>c.name==='set_role_modules').every(c=>c.args.p_changes.length===1&&c.args.p_changes[0].route_key==='donors')));
  await page.locator('[data-module-toggle=donors]').check();page.once('dialog',d=>d.dismiss());await page.locator('[data-module-role]').selectOption('FINANZAS');check('unsaved role changes are protected',(await page.locator('[data-module-role]').inputValue())==='ASISTENTE_OPERACIONES');await page.locator('[data-module-toggle=donors]').uncheck();await page.locator('[data-module-role]').selectOption('FINANZAS');
  await page.locator('[data-module-search]').fill('proveedores');check('module catalog can be searched',await page.locator('[data-module-toggle]').count()===1);await page.locator('[data-module-search]').fill('');
  await page.setViewportSize({width:390,height:844});check('role module configuration fits mobile viewport',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(out,'role-modules-mobile.png'),fullPage:false});
  await page.evaluate(async()=>{fixture.error={message:'Fallo de política simulado'};try{await window.canRoute('donors');window.policyFailedClosed=false}catch{window.policyFailedClosed=true}fixture.error=null});check('unavailable policy does not fall back to allowing routes',await page.evaluate(()=>window.policyFailedClosed));check('no browser runtime errors',errors.length===0);
 }catch(err){failure=err.message;console.error(err)}finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({status:failure?'FAIL':'PASS',checks,errors,failure,production_data_used:false},null,2));await browser?.close();await new Promise(r=>server.close(r))}if(failure)process.exitCode=1;else console.log(checks.length+'/'+checks.length+' role module browser checks passed');
})().catch(e=>{console.error(e);process.exitCode=1});
