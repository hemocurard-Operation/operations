import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const norm=(v:string)=>v.normalize('NFD').replace(/\p{Diacritic}/gu,'').toLowerCase();
const words=(v:string)=>new Set(norm(v).split(/[^a-z0-9]+/).filter(Boolean));

Deno.serve(async (req:Request)=>{
  if(req.method!=='POST') return new Response('Method not allowed',{status:405});
  try{
    const auth=req.headers.get('Authorization')||'';
    if(!auth) return Response.json({error:'AUTH_REQUIRED'},{status:401});
    const url=Deno.env.get('SUPABASE_URL')!;
    const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
    const sb=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
    const {action='tutor',role='USUARIO',question=''}=await req.json();
    const q=String(question).trim();
    if(!q) return Response.json({answer:'Describe la tarea o el error que quieres revisar.',source:'approved_training_documents',generative:false,clinical_decision:false});

    if(action==='exercise'){
      const {data:catalog,error}=await sb.from('vw_my_training_catalog').select('program_code,title,critical_process,practices,microlearning').limit(5);
      if(error) throw error;
      const rows=(catalog||[]).filter((x:any)=>x);
      if(!rows.length) return Response.json({answer:'No existe todavía un programa aprobado y asignado a tu puesto. Solicita a Calidad que valide la asignación y la vigencia del contenido.',source:'approved_training_documents',generative:false,clinical_decision:false});
      const p=rows[Math.floor(Math.random()*rows.length)] as any;
      const practices=Array.isArray(p.practices)?p.practices:[];
      const item=practices[Math.floor(Math.random()*Math.max(practices.length,1))];
      return Response.json({answer:`Ejercicio: ${item?.label||p.critical_process}. Explica el flujo correcto, qué evidencia conservarías y qué decisión no debes tomar fuera de tu autoridad.`,source:'approved_training_documents',generative:false,clinical_decision:false});
    }

    const {data,error}=await sb.from('vw_training_tutor_knowledge').select('role_scope,keywords,answer,document_code,title,version');
    if(error) throw error;
    const qwords=words(q);
    const candidates=(data||[]).filter((x:any)=>!x.role_scope?.length||x.role_scope.includes(String(role)));
    let best:any=null,bestScore=0;
    for(const x of candidates){
      const ks=(x.keywords||[]).map((k:string)=>norm(k));
      const score=ks.reduce((n:number,k:string)=>n+(qwords.has(k)||norm(q).includes(k)?1:0),0);
      if(score>bestScore){best=x;bestScore=score;}
    }
    if(!best){
      return Response.json({answer:'No encuentro una instrucción aprobada y vigente para este caso. Registra el contexto y escala a Calidad, Encargada de Laboratorio o Gerencia Técnica según corresponda.',source:'approved_training_documents',generative:false,clinical_decision:false});
    }
    const prefix=action==='explain_error'?'Orientación para el error: ':'';
    return Response.json({answer:prefix+best.answer,source:`${best.document_code} v${best.version}`,generative:false,clinical_decision:false});
  }catch(error){
    return Response.json({error:String(error),answer:'No fue posible consultar la base aprobada de capacitación. No tomes decisiones clínicas a partir de este error; escala el caso.'},{status:400});
  }
});
