// Unsubmitted drafts only. Stored per account/branch; expire after seven days and clear on sign-out.
const DB='hemocura-crm-drafts-v1',TTL=7*86400000;
async function database(){return new Promise((resolve,reject)=>{const r=indexedDB.open(DB,1);r.onupgradeneeded=()=>r.result.createObjectStore('drafts');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)})}
export async function crmDraft(key,value,remove=false){
 const db=await database();try{return await new Promise((resolve,reject)=>{
  const tx=db.transaction('drafts','readwrite'),store=tx.objectStore('drafts');let result;
  if(remove)store.delete(key);
  else if(value!==undefined)store.put({draft_version:2,expires_at:Date.now()+TTL,value},key);
  else{
   const request=store.get(key);request.onsuccess=()=>{
    const saved=request.result;if(!saved)return;
    const expiry=saved.draft_version===2?saved.expires_at:saved.saved_at?Date.parse(saved.saved_at)+TTL:Date.now()+TTL;
    if(!Number.isFinite(expiry)||expiry<=Date.now()){store.delete(key);return}
    result=saved.draft_version===2?saved.value:saved;
    if(saved.draft_version!==2)store.put({draft_version:2,expires_at:expiry,value:result},key);
   };
  }
  // Remove expired drafts for other branches/accounts too; never touch saved application records.
  const cursor=store.openCursor();cursor.onsuccess=()=>{const c=cursor.result;if(!c)return;const v=c.value;const expiry=v?.draft_version===2?v.expires_at:v?.saved_at?Date.parse(v.saved_at)+TTL:null;if(expiry!==null&&(!Number.isFinite(expiry)||expiry<=Date.now()))c.delete();c.continue()};
  tx.oncomplete=()=>resolve(result);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error||Error('No se pudo guardar el borrador.'));
 })}finally{db.close()}
}
export async function clearCrmDrafts(){const db=await database();try{await new Promise((resolve,reject)=>{const tx=db.transaction('drafts','readwrite');tx.objectStore('drafts').clear();tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error)})}finally{db.close()}}
