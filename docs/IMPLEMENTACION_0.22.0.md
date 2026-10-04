# HemoCura v0.22.0 — Implementación

## Orden
1. Subir SAFE PATCH.
2. En Supabase > SQL Editor ejecutar:
   `sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql`
3. Recargar HemoCura.
4. Probar:
   - Requisiciones
   - Inspecciones
   - SGC
   - Control Documental
   - Compliance
5. Ejecutar QA Técnico.

## Nuevos flujos
- Inspección → Hallazgo → Incidencia → NC → CAPA.
- Requisición → Autorización → Entrega → Recepción.
- Documento → Cambio → Aprobación → Vigencia.
- Riesgo → Control → Tratamiento → Evidencia → Revisión.

## Guardrails
- No reintroduce CRM, ventas, pricing o rentabilidad.
- Clinical Core continúa SHADOW/BLOCKED.
- Compliance jurídico requiere validación legal.
