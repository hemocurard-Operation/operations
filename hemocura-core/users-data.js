import { getSupabase } from './supabase.js';

async function callAdminUsers(action,payload={}){
  const {data,error}=await getSupabase().functions.invoke('admin-users',{body:{...payload,action}});
  if(error){
    let message=error.message||'No se pudo completar la solicitud';
    const status=error.context?.status;
    try{
      const body=await error.context?.clone().json();
      if(typeof body?.error==='string') message=body.error;
    }catch{ /* A network or gateway response may not contain JSON. */ }
    if(/already been registered|email_exists|email address.*already/i.test(message)){
      message='Ya existe una cuenta con este correo. Búsquela en Usuarios y roles para revisar sus accesos; no necesita crearla de nuevo.';
    }else if(status===401){
      message='La sesión venció o no es válida. Inicie sesión de nuevo antes de continuar.';
    }else if(/Failed to fetch|Failed to send a request/i.test(message)){
      message='No se pudo conectar. Verifique la conexión y actualice la lista de usuarios antes de volver a crear la cuenta.';
    }
    throw new Error(message);
  }
  if(data?.error) throw new Error(data.error);
  return data;
}

export async function loadUsersAdmin(){return callAdminUsers('list')}
export async function inviteUser(payload){return callAdminUsers('invite',payload)}
export async function createUser(payload){return callAdminUsers('create',payload)}
export async function addUserRole(payload){return callAdminUsers('add_role',payload)}

export async function removeUserRole(payload){return callAdminUsers('remove_role',payload)}
export async function changeUserPassword(payload){return callAdminUsers('change_password',payload)}
