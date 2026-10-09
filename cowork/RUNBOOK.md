# HemoCura Cowork v1 · Runbook

## Inicio de una iteración

1. Leer `CONTROL_CENTER.md`.
2. Confirmar la próxima acción segura en `TASK_QUEUE.md`.
3. Revisar CI del branch/PR activo.
4. Consultar Supabase en modo read-only cuando el cambio dependa del runtime.
5. Confirmar que no exista un STOP previo.

## Ejecución

`PREFLIGHT → PATCH → VALIDATE → CI → SMOKE → DOCTOR → GATE`

### PREFLIGHT

Debe producir evidencia de estado actual, dependencias y riesgos. No modifica producción.

### PATCH

Debe ser mínimo, forward-only y auditable. No usar `DROP TABLE`, `TRUNCATE`, `DISABLE RLS` ni claves privilegiadas en frontend salvo un plan excepcional explícitamente aprobado.

### VALIDATE

Debe comprobar el efecto real del patch y detectar estados parciales.

### CI

Ejecutar al menos los gates aplicables:

- Migration Security Linter
- Runtime Contract Gate
- Release Readiness Doctor
- Remediation Sequencer

### SMOKE

Frontend: navegador/producción candidata.
Backend: RPC/schema/flow específico.

### DOCTOR

Consolidar estado técnico, seguridad, operación y release.

### GATE

- PASS → siguiente etapa.
- ATTENTION → puede continuar solo si no afecta seguridad, clínica o integridad.
- STOP → reparar antes de continuar.

## Cierre de una iteración

Actualizar:

- `CONTROL_CENTER.md`
- `STATUS.json`
- `TASK_QUEUE.md`
- documento de estado de la iteración
- PR correspondiente

## Incidente durante despliegue

Registrar exactamente:

`versión → URL → archivo/objeto → error → evidencia → causa → corrección mínima → retest → gate`

No borrar evidencia ni ocultar fallos con permisos más amplios.
