# Despliegue seguro

## Método recomendado
Para una instalación HemoCura ya funcional:

**usar siempre el SAFE PATCH**.

Esto conserva:
- `js/config.js`;
- credenciales públicas correctas;
- Auth;
- configuración específica del proyecto.

## Antes de subir
Abrir `status.html` después del despliegue.

Debe mostrar:
- VERSION.json = 0.16.0;
- archivos = OK;
- js/config.js = Configuración personalizada detectada.

Si muestra:
`CONFIG PLACEHOLDER DETECTADO`

no continuar con QA ni Go-Live.
