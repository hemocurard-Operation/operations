import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const kb = [
  {keys:["reporte","diario"],answer:"Abre Reporte Operativo Diario, confirma fecha, sucursal y responsable, registra lotes, inventario y despachos, valida balances y guarda borrador. Enviar a revisión y cerrar son acciones distintas."},
  {keys:["permission","denied"],answer:"Conserva el mensaje exacto, usuario, rol, sucursal, módulo, acción y hora. Revisa autenticación, permiso requerido, alcance de sucursal, RLS y RPC. No concedas privilegios amplios como atajo."},
  {keys:["diferido","donante"],answer:"Selecciona DIFERIDO y documenta el motivo. La Suite organiza el registro, pero la elegibilidad depende de revisión humana autorizada."},
  {keys:["tamizaje","reactivo"],answer:"Cada prueba y resultado debe seleccionarse explícitamente. El sistema no debe asumir resultados ni interpretar el registro como liberación clínica automática."},
  {keys:["cadena","frío"],answer:"Detecta, documenta, contiene y escala según el procedimiento. La disponibilidad en inventario no sustituye la revisión de una excursión térmica."},
  {keys:["certificado","vigencia"],answer:"La constancia oficial requiere práctica supervisada, evaluación aprobada, instructor autorizado y segregación participante/evaluador. La vigencia se controla en Competencias."}
];

const exercises: Record<string,string[]> = {
  ASISTENTE_OPERACIONES:["Simula un reporte diario con un lote desbalanceado y explica qué harías antes de enviarlo.","Registra un donante DIFERIDO con motivo documentado y explica qué decisión NO toma el sistema."],
  ENCARGADA_LABORATORIO:["Analiza una excursión de cadena de frío y describe contención, evidencia y escalamiento.","Revisa un panel de tamizaje con un resultado pendiente y explica por qué no equivale a liberación."],
  MEDICO_GERENTE_TECNICO:["Revisa una unidad con trazabilidad incompleta y describe los criterios que deben verificarse antes de una decisión humana autorizada."],
  CALIDAD:["Construye una CAPA desde hallazgo hasta verificación de eficacia y cierre."],
  SUPER_USUARIO:["Diagnostica un permission denied sin ampliar privilegios y documenta cada capa revisada."],
  GERENCIA_SOCIO:["Prioriza tres excepciones de capacitación por riesgo, responsable y fecha de acción."],
  TI:["Clasifica un fallo entre frontend, autenticación, RLS y RPC; define el smoke test posterior a la corrección."]
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", {status:405});
  try {
    const {action="tutor", role="USUARIO", question=""} = await req.json();
    const q = String(question).trim();
    if (!q) return Response.json({answer:"Describe la tarea o el error que quieres revisar."});
    const low = q.toLowerCase();
    let answer = "Confirma la sucursal, el módulo y el objetivo del proceso. Usa datos verificables y conserva trazabilidad. Si existe una decisión clínica, detente y escálala al profesional autorizado.";
    if (action === "exercise") {
      const list = exercises[String(role)] || ["Describe el flujo correcto, los controles y los límites de autoridad para tu tarea actual."];
      answer = list[Math.floor(Math.random()*list.length)];
    } else {
      const hit = kb.find(x => x.keys.every(k => low.includes(k))) || kb.find(x => x.keys.some(k => low.includes(k)));
      if (hit) answer = hit.answer;
      if (action === "explain_error" && low.includes("permission")) answer = kb[1].answer;
    }
    return Response.json({answer, source:"approved_training_kb", generative:false, clinical_decision:false});
  } catch (error) {
    return Response.json({error:String(error)}, {status:400});
  }
});
