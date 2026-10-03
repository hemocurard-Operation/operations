# Diagnóstico v0.3.0

Secuencia:
[HEMOCURA_BOOT]
→ [HEMOCURA_AUTH]
→ [HEMOCURA_ROUTER]
→ [HEMOCURA_VIEW]

Si el menú aparece pero una vista no:
- revisar router.js
- revisar views.js

Si no aparece layout:
- revisar layout.js
- revisar bootstrap.js

Si vuelve a login:
- revisar auth.js / Supabase
