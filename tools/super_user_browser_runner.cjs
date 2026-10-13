const fs=require('node:fs'),http=require('node:http'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[path.join(__dirname,'../tests/wave50')]}));
(async()=>{
 const root=path.resolve(__dirname,'..');let browser;const checks=[];
 const server=http.createServer((req,res)=>{if(req.url==='/'){res.setHeader('Content-Type','text/html');return res.end('<div id="root"></div>')}if(req.url==='/hemocura-core/users.js'){res.setHeader('Content-Type','text/javascript');return res.end(fs.readFileSync(path.join(root,'hemocura-core/users.js')))}res.writeHead(404);res.end()});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;
 try{
 browser=await chromium.launch({executablePath:fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':undefined,args:['--no-sandbox','--disable-dev-shm-usage']});const page=await browser.newPage();
 await page.route('**/users-data.js',r=>r.fulfill({contentType:'text/javascript',body:`const noop=async()=>({});export const inviteUser=noop,createUser=noop,addUserRole=noop,removeUserRole=noop;export async function changeUserPassword(p){window.calls.push(p);if(window.fail)throw Error('Cambio rechazado');return{message:'Clave cambiada correctamente.'}};export async function loadUsersAdmin(){return{caller_user_id:'caller',roles:[{id:'super',code:'SUPER_USUARIO',name:'Super Usuario'}],branches:[{id:'branch',active:true,name:'Santiago'}],users:[{id:'caller',full_name:'Super Usuario de prueba',active:true,roles:[{role_id:'super',role_code:'SUPER_USUARIO',role_name:'Super Usuario',branch_id:'branch'}]},{id:'inactive',full_name:'Inactivo',active:false,roles:[]}]}};`}));
 await page.goto(origin);await page.evaluate(async()=>{window.calls=[];await (await import('/hemocura-core/users.js')).mountUsers(document.querySelector('#root'))});
 const test=(label,ok)=>{assert(ok,label);checks.push(label)};
 test('inactive account password control disabled',await page.locator('[data-password-user="inactive"]').isDisabled());
 await page.locator('[data-password-user="caller"]').click();const form=page.locator('#password-form');
 await form.locator('[name=password]').fill('synthetic-key-123');await form.locator('[name=confirmation]').fill('different-key-123');await form.locator('button').click();
 test('mismatched password makes no request',await page.evaluate(()=>window.calls.length===0));
 await form.locator('[name=confirmation]').fill('synthetic-key-123');await form.locator('button').click();await page.waitForFunction(()=>window.calls.length===1);
 test('exact target sent',await page.evaluate(()=>window.calls[0].user_id==='caller'&&window.calls[0].password==='synthetic-key-123'));
 test('successful request clears secret',await form.locator('[name=password]').inputValue()===''&&await form.locator('[name=confirmation]').inputValue()==='');
 await form.locator('[name=password]').fill('synthetic-key-123');await page.locator('#password-close').click();test('closing clears secret',await form.locator('[name=password]').inputValue()==='');
 await page.locator('[data-password-user="caller"]').click();await page.evaluate(()=>window.fail=true);await form.locator('[name=password]').fill('synthetic-key-123');await form.locator('[name=confirmation]').fill('synthetic-key-123');await form.locator('button').click();await page.waitForFunction(()=>document.querySelector('#password-status').textContent==='Cambio rechazado');test('failed request clears secret',await form.locator('[name=password]').inputValue()==='');
 console.log('PASS browser:',checks.length,'checks');if(process.env.HEMOCURA_SUPER_BROWSER_REPORT)fs.writeFileSync(process.env.HEMOCURA_SUPER_BROWSER_REPORT,JSON.stringify({checks,production_verified:false},null,2));
 }finally{await browser?.close();await new Promise(r=>server.close(r))}
})().catch(e=>{console.error(e);process.exitCode=1});
