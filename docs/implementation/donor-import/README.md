# Antecedentes de importación de donantes

El módulo distingue datos declarados por un archivo de registros operativos creados en HemoCura. `donor_import_metadata` conserva procedencia y antecedentes por ficha, bajo las políticas RLS existentes de donantes. El listado general excluye ese JSON; se consulta únicamente al abrir una ficha. Un trigger impide modificar la procedencia desde las cuentas de la aplicación, manteniendo la edición de nombre, teléfono, sexo y grupo sanguíneo. Las fichas importadas con cédula pendiente pueden completar sus datos sin inventar números.

La pantalla presenta fechas de donación declaradas, notas originales, contactos previos y fechas previstas con indicación de su origen. Esos antecedentes no crean donaciones/unidades, contactos atribuidos a usuarios actuales ni citas confirmadas. Los estados originales quedan conservados; importar datos no concede elegibilidad clínica. Las nuevas fichas de la carga permanecen `PENDIENTE`.

La limpieza normaliza espacios, prefijos numéricos de nombres y formato telefónico; conserva los valores originales. Solo consolida registros de identidad normalizada coincidente con cédula/campo de identificación compartido, teléfono compartido o datos de origen idénticos. Las identidades contradictorias y filas sin nombre identificable quedan para revisión. No completa dígitos de cédulas ni elige un grupo sanguíneo ante contradicciones.

La carga es idempotente por código determinista derivado del archivo y fila de origen. Esta entrega inicial contiene únicamente los registros con sucursal explícita; el resto requiere asignación confirmada para respetar los permisos por sucursal.

El Excel, los datos personales, notas de salud, teléfonos, cédulas, scripts SQL con sus valores y el detalle de filas excluidas permanecen fuera del repositorio público. El resumen publicado contiene solo cifras agregadas. La migración contiene únicamente estructura y reglas, sin datos del archivo.
