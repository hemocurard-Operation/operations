# HemoCura Cowork v1 · Control Center

Línea base activa: frontend runtime `0.44.2`, database baseline `0.44`.

| Dominio | Estado | Evidencia / gate | Próxima acción |
|---|---|---|---|
| GitHub CI | PASS | Security Linter + Runtime Contract + Release Doctor + Sequencer | Mantener verde |
| Frontend | PASS | C11.2 merged + browser smoke SUCCESS + Pages deploy SUCCESS | Mantener estable |
| Database | PASS BASELINE | v0.44 | Ejecutar C12 antes de v0.45 |
| Schema Drift | PASS | Runtime Contract | Vigilar cambios |
| RLS | STOP | Hardening pendiente | C12/C13-A/F/G |
| RPC Security | STOP | Hardening pendiente | C13-C1/C2A/C2B/D |
| Anonymous Surface | STOP | Hardening pendiente | C13-B1/B2/E/H |
| Role Model | STOP | Faltan roles/hardening | C12 |
| Clinical Guardrails | SAFE_LIMITED | No activar automatismos clínicos | C14 |
| UAT | STOP | Sin runs 1.0.0 | Después de hardening |
| Sign-offs | STOP | Sin firmas 1.0.0 | Después de UAT |
| Final Release Gate | NOT_READY | C13-K | Recalcular al cerrar la cola |

## S01 cerrado

- PR #1: MERGED
- Merge SHA: `1d442aca8b3eca7d6b6d8a5a75f1e9ccd2f03d92`
- C11.2 browser smoke: SUCCESS (`37607415945`)
- GitHub Pages build/deploy: SUCCESS (`37607415753`)

## Próxima acción segura

`S02_C12_SECURITY_HARDENING`

## Semáforo

- `PASS`: evidencia suficiente para continuar.
- `ATTENTION`: no bloquea, pero requiere seguimiento.
- `STOP`: no avanzar.
- `SAFE_LIMITED`: permitido bajo guardrails explícitos.
- `NOT_READY`: release no autorizado.

## Regla de actualización

Cada iteración debe actualizar este tablero solamente después de obtener evidencia del sistema correspondiente. Un archivo generado no cambia el estado runtime.
