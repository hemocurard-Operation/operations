// Public conversion only; no credential, role, or account lookup. Supabase Auth validates passwords.
export const USERNAME_PATTERN=/^[a-z][a-z0-9._-]{2,39}$/;
const DOMAIN='login.hemocura.invalid';
export function normalizeUsername(value){
 if(typeof value!=='string')throw Error('El usuario debe ser texto');
 const username=value.trim().toLowerCase();
 if(!USERNAME_PATTERN.test(username))throw Error('Use un usuario de 3 a 40 caracteres: empiece con una letra y utilice letras sin acentos, números, punto, guion o guion bajo');
 return username;
}
export function loginEmail(identifier){
 const value=String(identifier??'').trim().toLowerCase();
 return value.includes('@')?value:normalizeUsername(value)+'@'+DOMAIN;
}
export function accountLogin(usernameValue,emailValue,action){
 const username=usernameValue===undefined||usernameValue===null||usernameValue===''?null:normalizeUsername(usernameValue);
 const contact=typeof emailValue==='string'?emailValue.trim().toLowerCase():'';
 if(contact&&(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact)||contact.endsWith('@'+DOMAIN)))throw Error('Correo de contacto no válido');
 if(!username&&!contact)throw Error('Indique un usuario de acceso o un correo para el acceso existente');
 if(username&&action==='invite')throw Error('Para usuarios personales seleccione acceso inmediato con clave; el correo de contacto no recibe enlaces de acceso');
 return {username,contact_email:contact||null,email:username?loginEmail(username):contact};
}
