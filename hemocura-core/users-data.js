import { getSupabase } from './supabase.js';

async function callAdminUsers(action,payload={}){
  const {data,error}=await getSupabase().functions.invoke('admin-users',{body:{action,...payload}});
  if(error) throw new Error(error.message||'Error en admin-users');
  if(data?.error) throw new Error(data.error);
  return data;
}

export async function loadUsersAdmin(){return callAdminUsers('list')}
export async function inviteUser(payload){return callAdminUsers('invite',payload)}
export async function createUser(payload){return callAdminUsers('create',payload)}
export async function addUserRole(payload){return callAdminUsers('add_role',payload)}
export async function removeUserRole(payload){return callAdminUsers('remove_role',payload)}
export async function setUserActive(payload){return callAdminUsers('set_active',payload)}
