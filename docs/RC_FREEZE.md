# RC Freeze

## Objetivo
Evitar que errores de caché, archivos incompletos o versiones mezcladas se confundan con errores de Supabase.

## Flujo
1. Desplegar v0.14.0.
2. Abrir `#freeze`.
3. Confirmar VERSION.json.
4. Ejecutar self-test.
5. Revisar caché.
6. Ejecutar `#qa`.
7. Ejecutar `#release`.
8. Congelar cambios funcionales.
9. Corregir solo hallazgos.
10. Promover a v1.0.0 únicamente después de QA real.

## Señal de problema de caché
- código corregido pero navegador muestra error anterior;
- versión visible no coincide;
- Network sirve JS antiguo;
- archivos nuevos dan 404 intermitente.

Use "Limpiar caché local y Service Workers" y recargue.
