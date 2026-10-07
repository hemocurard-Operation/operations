# HemoCura Cowork v1 · Control Center

Última línea base conocida: frontend candidate `0.44.2`, database baseline `0.44`.

| Dominio | Estado | Evidencia / gate | Próxima acción |
|---|---|---|---|
| GitHub CI | PASS | Security Linter + Runtime Contract + Release Doctor + Sequencer | Mantener verde |
| Frontend | CANDIDATE | C11.2 preparado | Ejecutar smoke y merge |
| Database | PASS BASELINE | v0.44 | No avanzar a v0.45 aún |
| Schema Drift | PASS | Runtime Contract | Vigilar cambios |
| RLS | STOP | Hardening pendiente | C12/C13-A/F/G |
| RPC Security | STOP | Hardening pendiente | C13-C1/C2A/C2B/D |
| Anonymous Surface | STOP | Hardening pendiente | C13-B1/B2/E/H |
| Role Model | STOP | Faltan roles/hardening | C12 |
| Clinical Guardrails | SAFE_LIMITED | No activar automatismos clínicos | C14 |
| UAT | STOP | Sin runs 1.0.0 | Después de hardening |
| Sign-offs | STOP | Sin firmas 1.0.0 | Después de UAT |
| Final Release Gate | NOT_READY | C13-K | Recalcular al cerrar la cola |

## Próxima acción segura

`S01_C11_2_FRONTEND_SMOKE_MERGE`

## Semáforo

- `PASS`: evidencia suficiente para continuar.
- `ATTENTION`: no bloquea, pero requiere seguimiento.
- `STOP`: no avanzar.
- `SAFE_LIMITED`: permitido bajo guardrails explícitos.
- `NOT_READY`: release no autorizado.

## Regla de actualización

Cada iteración debe actualizar este tablero solamente después de obtener evidencia del sistema correspondiente. Un archivo generado no cambia el estado runtime.
