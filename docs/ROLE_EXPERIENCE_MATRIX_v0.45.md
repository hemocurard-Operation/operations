# HemoCura v0.45 · Matriz de roles y experiencia

## Roles operativos

| Rol | Propósito | Acceso prioritario |
|---|---|---|
| ENCARGADA_LABORATORIO | Supervisión técnica del laboratorio | Donantes, tamizaje, producción, inventario sanguíneo, calidad analítica, cadena de frío |
| ASISTENTE_OPERACIONES | Captura y apoyo operativo diario | Despachos, requisiciones, insumos, donantes, ventas/salidas, abastecimiento |
| SUPER_USUARIO | Administración integral del sistema | Todos los permisos activos; no sustituye decisiones clínicas humanas |
| MEDICO_GERENTE_TECNICO | Supervisión médica/técnica y liberación humana autorizada | Flujo sanguíneo, calidad analítica, hemovigilancia, SGC, cadena de frío, revisión de dirección |
| SOCIO | Visión ejecutiva de solo lectura predominante | Centro de mando, BI, proyectos, revisión de dirección, calidad, ventas |

## Estado de cuentas

Los roles anteriores están definidos en Supabase. La creación de cuentas Auth requiere una identidad real (correo electrónico/login) y un método de alta seguro. No se crean credenciales ficticias ni se insertan usuarios directamente en `auth.users`.

## Guardrails

- No elegibilidad automática del donante.
- No compatibilidad transfusional automática.
- No liberación de componentes sin decisión humana autorizada.
- `SUPER_USUARIO` es un rol de plataforma y no reemplaza autoridad clínica.
- `MEDICO_GERENTE_TECNICO` puede contar con `UNIT_RELEASE`, que representa una acción humana controlada, no una liberación automática.
