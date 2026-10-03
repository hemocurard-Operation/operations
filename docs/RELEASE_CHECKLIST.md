# Release Checklist — HemoCura v0.12.0 RC

## Infraestructura
- [ ] GitHub Pages carga `/operations/`
- [ ] HTTPS activo
- [ ] Supabase accesible
- [ ] js/config.js correcto
- [ ] sin service_role en frontend

## Autenticación
- [ ] Login
- [ ] Persistencia
- [ ] Logout
- [ ] RLS por usuario/rol/sucursal

## Operación
- [ ] Dashboard
- [ ] Ventas
- [ ] Despachos
- [ ] Inventario
- [ ] Costos
- [ ] Calidad
- [ ] Planificación
- [ ] Configuración

## Datos
- [ ] Backup previo
- [ ] Ventas conciliadas
- [ ] Despachos conciliados
- [ ] Inventario revisado
- [ ] Costos validados
- [ ] NC/CAPA revisadas

## Guardrails
- [ ] Forecast marcado SHADOW
- [ ] FEFO clínico no activo
- [ ] Cold chain blocking no activo
- [ ] Donor-recipient traceability no usada como control operativo

## Go / No-Go
GO solamente si todos los controles críticos están aprobados.
