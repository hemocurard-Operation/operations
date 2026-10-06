# HemoCura · C13-A · Clasificación RLS

## Evidencia real

Supabase Security Advisor reporta 19 tablas en `public` con RLS habilitado y sin policies. El preflight ejecutado contra la base real confirmó además que `anon` y `authenticated` conservan grants amplios sobre esas tablas. La mayoría están vacías; las excepciones actuales son `app_feature_flags` (11), `hc_gate_versions` (25), `hc_gate_requirements` (76) y `system_operating_mode` (1).

## Matriz de tratamiento

| Tabla | Clase | Lectura propuesta | Escritura propuesta | Alcance |
|---|---|---|---|---|
| app_feature_flags | configuración crítica | BLOOD_INVENTORY_VIEW/WRITE o RELEASE_GATE_VIEW | ACCESS_ADMIN | global |
| blood_unit_tests | clínico/tamizaje | SCREENING_VIEW | SCREENING_WRITE | sucursal de blood_units |
| deployment_events | infraestructura release | RELEASE_GATE_VIEW | ACCESS_ADMIN, solo INSERT | global / append-only |
| deployment_releases | infraestructura release | RELEASE_GATE_VIEW | ACCESS_ADMIN, INSERT/UPDATE | global |
| dispatch_unit_allocations | operación despacho | DISPATCH_VIEW | DISPATCH_WRITE | sucursal del despacho |
| hc_gate_requirements | metadatos de gate | RELEASE_GATE_VIEW | sin escritura directa | global |
| hc_gate_versions | metadatos de gate | RELEASE_GATE_VIEW | sin escritura directa | global |
| integration_outbox | integración interna | ACCESS_ADMIN | sin escritura directa | global |
| inventory_lots | inventario | BLOOD_INVENTORY_VIEW | BLOOD_INVENTORY_WRITE | branch_id |
| migration_issues | diagnóstico migración | RELEASE_GATE_VIEW / ACCESS_ADMIN | sin escritura directa | global |
| product_control_modes | configuración clínica | BLOOD_INVENTORY_VIEW/WRITE | ACCESS_ADMIN | global |
| recipient_issues | despacho / receptor | DISPATCH_VIEW o HEMOVIGILANCE_VIEW | DISPATCH_WRITE | sucursal del despacho |
| stg_requerimientos | staging | ACCESS_ADMIN | sin escritura directa | global |
| stg_resp_despachos | staging | ACCESS_ADMIN | sin escritura directa | global |
| storage_devices | cadena de frío | COLD_CHAIN_VIEW | COLD_CHAIN_WRITE | branch_id |
| storage_excursions | cadena de frío | COLD_CHAIN_VIEW | COLD_CHAIN_WRITE, solo UPDATE | sucursal del dispositivo |
| system_operating_mode | configuración crítica | DASHBOARD_VIEW o RELEASE_GATE_VIEW | ACCESS_ADMIN, solo UPDATE | global |
| temperature_policies | cadena de frío | COLD_CHAIN_VIEW | COLD_CHAIN_WRITE | sucursal del dispositivo |
| temperature_readings | cadena de frío | COLD_CHAIN_VIEW | COLD_CHAIN_WRITE, solo INSERT | sucursal del dispositivo |

## Guardrails

- `anon`: sin acceso directo a las 19 tablas.
- Se eliminan grants como `TRUNCATE`, `TRIGGER` y `REFERENCES` para roles de navegador.
- No se habilita DELETE directo en tablas clínicas, de cadena de frío o de trazabilidad.
- `temperature_readings` queda append-only para el frontend.
- `storage_excursions` se crea por lógica de evaluación; el frontend solo puede resolver/actualizar con permiso de cadena de frío.
- `integration_outbox`, tablas `stg_*` y tablas `hc_gate_*` no aceptan escritura directa desde el navegador.
- No se cambia ninguna decisión clínica automática ni se habilita FEFO/liberación clínica por esta migración.

## Gate

`C13A_01_RLS_POLICY_CANDIDATE.sql` es candidato, no está aplicado. Ejecutar primero `C13A_00_PREFLIGHT_RLS_NO_POLICY.sql`; después de aplicar, ejecutar `C13A_90_VALIDATE_RLS_POLICIES.sql` y exigir PASS.
