# HemoCura v0.23.0

## Alcance
Operaciones + Sangre + SGC + Compliance + BI + Gestión de Proyectos.

## Orden
1. Subir SAFE PATCH sobre v0.22.0.
2. Ejecutar en Supabase:
   `sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql`
3. Recargar HemoCura.
4. Probar:
   - #sales
   - #donors
   - #screening
   - #bloodinventory
   - #bi
   - #projects
5. Ejecutar #qa.

## Regla
Ventas es un módulo de control de salidas y facturación, no CRM ni pipeline comercial.

## Guardrail
El sistema no decide elegibilidad clínica, compatibilidad transfusional ni liberación clínica automática.
