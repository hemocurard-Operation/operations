# Política de configuración v0.28

## Archivo protegido
`js/config.js`

Reglas:
1. Nunca incluirlo en SAFE PATCH.
2. Desde v0.28 tampoco se incluye en el paquete completo generado.
3. La plantilla es `js/config.example.js`.
4. La configuración productiva se mantiene únicamente en el repositorio/despliegue.
5. Nunca usar service_role, secret key o contraseña de base de datos en frontend.
6. La publishable/anon key es pública por diseño; la seguridad depende de RLS.
