# C13-H · Implementation Order

Esta iteración no debe aplicarse aislada.

Orden mínimo:

1. C12 · UAT / Release hardening → PASS
2. C13-A · RLS no-policy → PASS
3. C13-F · Broad policy hardening → PASS
4. C13-G · Grant ↔ RLS reconciliation → PASS
5. C13-E · Anonymous surface hardening → PASS
6. C13-H · Default privilege governance → PREFLIGHT → PATCH → VALIDATE

C13-H es preventivo: actúa sobre objetos FUTUROS. Las iteraciones previas corrigen la superficie EXISTENTE.

Después de C13-H, toda migración nueva debe declarar sus GRANT explícitos y acompañarlos de RLS o autorización RPC adecuada.
