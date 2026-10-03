# HemoCura Operations v0.15.0 RC

Etapa: verificación externa del despliegue.

## Nueva página
`/operations/status.html`

No requiere login ni conexión exitosa con Supabase.

## Objetivo
Separar cuatro clases de problemas:

1. GitHub Pages / publicación.
2. Archivos/rutas.
3. Caché/versiones antiguas.
4. Supabase/Auth/RLS.

## Secuencia recomendada
Si la aplicación falla:

1. Abrir `status.html`.
2. Copiar el reporte.
3. Si todo está OK, continuar con F12 y Supabase.
4. Si un archivo falla, corregir únicamente despliegue/ruta.
