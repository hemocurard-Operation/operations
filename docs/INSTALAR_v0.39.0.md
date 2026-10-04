# INSTALACIÓN — HemoCura v0.39.0

## Método recomendado: GitHub.com + Supabase (sin terminal)

### A. Antes de comenzar
1. Confirme que la versión base instalada es **v0.38.0**.
2. No edite ni reemplace `js/config.js`.
3. Descargue el archivo **SAFE PATCH** de esta versión.
4. Extraiga el ZIP en su computadora.

### B. Subir archivos usando GitHub.com
1. Abra el repositorio `hemocurard-operation/operations`.
2. Entre a la carpeta raíz del proyecto.
3. Pulse **Add file → Upload files**.
4. Arrastre el contenido del SAFE PATCH respetando las carpetas.
5. Verifique que **NO** aparece `js/config.js` en los archivos a subir.
6. Escriba el mensaje de commit:
   `HemoCura v0.39.0`
7. Pulse **Commit changes**.

### C. Ejecutar migración en Supabase
1. Abra Supabase.
2. Entre a **SQL Editor**.
3. Abra el archivo:
   `sql/39_COLD_CHAIN_v0_39.sql`
4. Copie todo su contenido.
5. Péguelo en una nueva consulta.
6. Pulse **Run**.
7. Debe terminar sin errores.

### D. Validar publicación
1. Espere la publicación de GitHub Pages.
2. Abra:
   `https://hemocurard-operation.github.io/operations/`
3. Haga recarga fuerte: **Ctrl + Shift + R**.
4. Cierre sesión y vuelva a entrar.
5. Abra:
   `#coldchain`

### E. Pruebas mínimas
1. Abrir #coldchain.
2. Registrar dispositivo en Supabase.
3. Agregar una lectura fuera de rango.
4. Confirmar que aparece como excursión.

### F. Antes de pasar a la siguiente versión
- Abra `#diagnostics`.
- Abra `#releasegate`.
- Confirme que no hay error de migración.
- Si aparece un error, no continúe hasta corregirlo.
