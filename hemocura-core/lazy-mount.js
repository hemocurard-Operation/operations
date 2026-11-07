// Route imports start only after the router has authorized the route.
export const lazyMount=(load,name)=>async(...args)=>{
 const module=await load();
 if(!args[0]?.isConnected)return;
 const mount=module[name];
 if(typeof mount!=='function')throw Error('No se pudo cargar la pantalla. Actualice para reintentar.');
 return mount(...args);
};
