# Verificación de Zemo — 22 de octubre de 2026

- `swift run --disable-sandbox AstroCoreChecks`: PASS. Diez casos cubren validación, límites de permisos, protocolo JSONL, Unicode fragmentado, stdout/stderr, entradas literales, cancelación y ejecutable ausente.
- Compatibilidad con el CLI instalado: los argumentos de ambos modos se verifican contra `codex exec --help`, sin invocar el modelo.
- Regresión corregida: `--ignore-user-config` pertenece a `codex exec`, no a la raíz del comando. El caso nuevo falló con salida 2 antes de corregirlo y pasa después.
- `bash scripts/build-app.sh`: compilación release y paquete local completados.
- Arte de Zemo inspeccionado: boyero australiano adulto en pixel art, traje espacial, cuatro patas y fondo transparente. El recurso se incluye dentro del paquete.

## Actualización del 24 de octubre de 2026

- `swift run --disable-sandbox AstroCoreChecks`: PASS.
- `bash scripts/build-app.sh`: reconstruido con los sprites nuevos (busto con casco, `Assets/sprites`). El arte descrito arriba (cuatro patas) ya no aplica.
- Envío real desde la interfaz (modo consulta): Zemo llegó a Codex, que ejecutó un comando (`git`) y respondió en español; informó que la carpeta no era un repositorio y que el sandbox bloqueó una caché temporal, lo esperado en solo lectura. Sin verificar aún: vista de actividad, «Nueva conversación» y modo edición.

## Auditoría del 25 de octubre de 2026

- Hallazgo 1 (media): el modo edición solo bloqueaba raíces exactas; `~/.ssh`, `~/.codex` o `~/Library` podían elegirse como carpeta editable. Ahora se rechazan los directorios ocultos del home, `~/Library` y rutas de sistema, con sus hijos. Prueba: `testEditRejectsSensitiveDirectoriesAndTheirChildren`.
- Hallazgo 2 (media): el proceso de Codex heredaba todo el entorno (claves como `ANTHROPIC_API_KEY`). Ahora `ChildEnvironment.sanitized` pasa solo HOME, PATH, idioma, proxy y variables `CODEX_*`/`OPENAI_*`/`SSL_CERT_*`/`XDG_*`. Prueba: `testChildEnvironmentDropsSecretsAndKeepsWhatCodexNeeds`. `codex login status` funciona con ese entorno.
- Ambas pruebas se escribieron antes y fallaron (no compilaban / no rechazaban); ahora `AstroCoreChecks` pasa completo.
- Sin corregir: salida de más de 4.000 líneas se descarta y podría perder el mensaje final; el llamado al shell del hijo puede salirse del grupo de procesos con `setsid`.

## Voz con atajo — 25 de octubre de 2026

- Pruebas escritas primero (no compilaban sin `DictationPolicy`): `DictationTests` cubre conservar el borrador, cancelar, resultados tardíos de una sesión anterior, resultado vacío, fallo, bloqueo durante una tarea y límite de 60 s. `swift run --disable-sandbox AstroCoreChecks`: PASS.
- `bash scripts/build-app.sh`: compila y empaqueta; `Info.plist` válido con las descripciones de micrófono y reconocimiento. La app arranca y sigue viva tras 4 s.
- **Sin verificar** (requiere audio y la sesión real del Mac): precisión del reconocimiento en español, los diálogos de permisos, que el atajo funcione desde otra app, que el micrófono se libere al cancelar y que el atajo ocupado muestre el aviso. Si el Mac no ofrece reconocimiento local en español, el dictado muestra la limitación en vez de enviar audio fuera.

## Motores Claude y Gemini — 25 de octubre de 2026

- Pruebas escritas primero (`EngineTests`): argumentos y permisos por motor, que el prompt no vaya en los argumentos, que el modo edición siga rechazando carpetas amplias y sensibles con cualquier motor, aislamiento de variables de entorno por proveedor y lectura de los flujos JSON de Claude y Gemini. `AstroCoreChecks`: PASS.
- Prueba real de extremo a extremo con el mismo código de la app (ejecutable de prueba fuera del proyecto):
  - Claude, consulta: leyó `pwd` y `git status` en la carpeta elegida y se negó a crear un archivo.
  - Claude, edición: creó `nuevo.txt`. **Hallazgo:** con `--permission-mode acceptEdits` también ejecutó `rm README.md` y lo borró. Se cambió a `default` con `Edit`/`Write` permitidos; repetida la prueba, `rm` se rechaza y el archivo queda intacto. La prueba unitaria impide volver a `acceptEdits`.
  - Gemini: ver abajo.
- Notion desde Claude: búsqueda real en un espacio de trabajo de prueba con el conector de la cuenta.
- Sin verificar: Notion/GitHub desde Codex tras el login, y la interfaz con el selector (compilada, no usada con clics).

## Verificación pendiente

El envío real de una instrucción desde la interfaz no está verificado. Computer Use rechazó el acceso a la app durante la revisión visual. La prueba directa del CLI desde el entorno administrado tampoco pudo iniciar su cliente interno (`Operation not permitted`); esto ocurrió antes de una respuesta del modelo. No se han desactivado permisos para sortear esos límites.

Para comprobarlo en la sesión normal del Mac, cierra Astro Boyero si sigue abierto, abre Zemo y envía: «Ejecuta pwd y dime en qué carpeta estamos. No modifiques archivos». Debe aparecer el directorio seleccionado y, en la vista de actividad, el comando y su salida. Si falla, el mensaje de error incluye los diagnósticos del CLI.

## Dictado: selección de variante local — 25 de octubre de 2026

- Síntoma: «Este Mac no tiene reconocimiento de voz local en español». Sonda con `SFSpeechRecognizer`: ninguna variante de español (es-CR, es-MX, es-ES, es-US, es-419, es-AR, es-CO, es-CL) tiene modelo local en este Mac; solo inglés. El aviso era correcto y la causa es que el Dictado del sistema solo tiene `en_GB`.
- Fallo real de código corregido: se tomaba la primera variante *disponible* (es-MX) y solo después se comprobaba si era local, sin probar las demás. Ahora se evalúan primero los idiomas del sistema y luego es-CR, es-MX, es-419, es-ES, es-US, es-AR, es-CO, es-CL, y se usa la primera con modelo local. Nunca se cae a reconocimiento en servidor.
- Pruebas escritas primero (no compilaban sin `spanishLocales`/`firstOnDevice`); `AstroCoreChecks`: PASS. `build-app.sh`: compila.
- Mensaje de error ahora indica añadir Español en Dictado > Idiomas.
- **Sin verificar:** dictado real con el modelo descargado (requiere que se active en Ajustes).

## Idioma de dictado (es/en) — 25 de octubre de 2026

- Este Mac tiene modelo local de inglés (`en-US`) pero no de español. Se añadió `DictationLanguage` (español por defecto) y el submenú «Idioma de dictado» en el menú de la huella; la elección se guarda en `ZemoDictationLanguage` y no cambia durante un dictado. Sigue sin haber reconocimiento en servidor.
- Pruebas escritas primero (no compilaban sin `locales(for:preferred:)`/`DictationLanguage`); `AstroCoreChecks`: PASS; `build-app.sh`: compila.
- **Sin verificar:** dictado real en inglés con audio y el submenú con clics.
