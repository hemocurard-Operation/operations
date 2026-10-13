# Lectura de cédula y consulta del intervalo de donación

`hemocura-core/cedula-reader.js` contiene normalización de cédula, comprobación orientativa del dígito verificador, extracción de texto etiquetado, OCR local y cálculo del intervalo. `cedula-reader-ui.js` integra foto, cámara y entrada por teclado/escáner en el módulo existente.

La consulta utiliza coincidencia exacta del número normalizado con `vw_donor_next_donation`, bajo los permisos de la cuenta y la sucursal. Presenta última donación, origen del dato, días transcurridos, próxima fecha calculada y días pendientes para completar 84 días. Sin fecha válida o con una fecha futura no afirma que el intervalo se haya cumplido. No consulta un padrón de la JCE ni acredita autenticidad documental o elegibilidad clínica. Un dígito verificador dudoso se muestra para revisión, preservando la posibilidad de localizar registros importados que necesitan corrección.

La foto/cámara propone nombre, cédula, sexo y fecha de nacimiento cuando el documento contiene etiquetas legibles. Los datos deben revisarse con el documento y confirmarse explícitamente antes de pasarlos a la ficha; Guardar ficha constituye una acción separada. Si la cédula coincide con una ficha visible se actualiza esa ficha, manteniendo ID e historial. Los permisos de solo lectura no permiten aplicar datos. No se infieren teléfono, grupo sanguíneo, fecha de donación ni aptitud clínica a partir del número.

El OCR Tesseract.js 6.0.1, core 6.0.0 y datos de idioma español 1.0.0 se sirven desde la misma web. Se carga al solicitar lectura de imagen. No se suben ni almacenan imágenes de cédulas, audio o video; el texto reconocido y la imagen se descartan al cerrar. La cámara se detiene al capturar, cerrar o abandonar el módulo. La instalación conserva manifiesto SHA-256 y licencias de los componentes públicos.

Validación: 20 pruebas de normalización/parser/calendario; 34 de interfaz con datos ficticios, incluidos consentimiento de revisión, coincidencia con ficha, datos ausentes y móvil; OCR real de un documento sintético con todas las peticiones locales GET y ninguna subida; 39 reglas SQL y 70 comprobaciones operativas. No se han utilizado imágenes reales de documentos ni se han cambiado identidades de los donantes importados durante las pruebas.

Migración: `supabase/migrations/20261013200735_donor_identity_capture.sql`. Agrega fecha de nacimiento opcional, rechaza fechas futuras y conserva RLS de la vista y los registros. La migración no contiene información de donantes ni imágenes.

Pruebas:

```sh
node tests/donors/cedula-rules.mjs
python tools/donors_postgres_runner.py
node tools/donors_browser_runner.cjs
node tools/cedula_ocr_runner.cjs
```
