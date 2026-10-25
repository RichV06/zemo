# Voz mediante atajo en Zemo

Estado: propuesta para revisión. Fecha: 25 de octubre de 2026.

## Objetivo
Ricardo quiere dar comandos y tareas por voz al Zemo flotante de macOS. Confirmó que la escucha debe activarse con un atajo. La voz alimenta el chat existente y conserva sus modos Consultar y Editar carpeta.

## Comportamiento propuesto
- Control + Opción + Z activa la escucha y muestra el chat incluso desde otra aplicación, mientras Zemo esté abierto. Una segunda pulsación detiene el dictado.
- Mostrar claramente cuándo escucha, cuándo prepara la transcripción y cuándo termina. Incluir un botón equivalente y Escape para cancelar.
- Transcribir español al borrador. Conservar cualquier texto previo y permitir revisar y corregir antes de enviar con Enter o el botón actual. No enviar automáticamente.
- Al cancelar, conservar el borrador anterior. Si no se detecta voz o falla el reconocimiento, no ejecutar ninguna tarea y explicar cómo volver a intentarlo.
- Bloquear un nuevo dictado mientras haya una tarea ejecutándose. Impedir cambios de carpeta o conversación durante una grabación.
- Limitar cada sesión a 60 segundos y detener el micrófono al cancelar, finalizar o salir. No escuchar continuamente ni usar palabra de activación.
- Solicitar permisos de micrófono y reconocimiento solo al primer uso. Si se deniegan, explicar cómo habilitarlos y mantener utilizable el chat escrito.
- Preferir reconocimiento local en español mediante macOS. No incorporar servicios de transcripción ni claves API. Si el reconocimiento local no está disponible, mostrar la limitación; no enviar audio a un servicio alternativo silenciosamente.
- No guardar audio ni transcripciones en disco. El texto enviado al chat se procesa mediante la sesión de Codex existente, igual que una instrucción escrita.
- Si otro programa ocupa el atajo, informar y conservar el acceso mediante el botón.

## Stack y estructura
Swift 6 en modo Swift 5, SwiftUI y AppKit, macOS 14+, sin paquetes de terceros. Incorporar captura/transcripción nativa y registro del atajo en Sources/AstroBoyero. Mantener la política comprobable de sesiones en Sources/AstroCore cuando corresponda. Tests en Tests/AstroCoreTests; permisos y metadatos en scripts/build-app.sh. Actualizar README.md y VALIDATION.md.

## Comandos de verificación
- Pruebas existentes y nuevas: `swift run --disable-sandbox AstroCoreChecks`.
- Compilación y empaquetado: `bash scripts/build-app.sh`.
- Apertura manual: `open dist/Zemo.app`.

## Estilo
Cuatro espacios, tipos UpperCamelCase y funciones lowerCamelCase. Seguir las guardas y los estados observables del proyecto; por ejemplo: `guard !isRunning else { return }`.

## Estrategia de pruebas
Escribir y ejecutar pruebas fallidas antes de implementar la política de dictado: preservación del borrador, cancelación, resultados tardíos de una sesión anterior, límites y bloqueo durante tareas. Ejecutar toda la suite y compilar el paquete. Revisar en la interfaz el atajo desde otra app, los estados y los errores. La precisión de voz, los permisos reales y la liberación del micrófono requieren una prueba con audio y macOS; registrar por separado lo que se pudo verificar y lo pendiente.

## Límites
- Siempre: conservar los permisos y la validación de tareas existentes; detener captura y liberar recursos al terminar; informar errores en español.
- Consultar antes: cambiar el atajo propuesto si entra en conflicto o introducir un servicio externo de voz.
- Nunca: ejecutar una transcripción sin envío explícito, guardar audio, habilitar escucha permanente o ampliar permisos de Codex.

## Criterios de aceptación
1. Pulsar el atajo desde otra aplicación abre Zemo e inicia una sesión visible de escucha.
2. Hablar en español y pulsar de nuevo deja una instrucción editable sin ejecutar nada.
3. Enter envía esa instrucción por el flujo existente y respeta el modo elegido.
4. Cancelar o fallar no pierde el borrador anterior ni deja el micrófono abierto.
5. Un permiso denegado, un atajo ocupado o reconocimiento local no disponible produce un mensaje útil y conserva el chat escrito.
6. Las pruebas existentes y nuevas pasan y la app se empaqueta correctamente. La validación documenta cualquier comprobación de audio pendiente.

## Decisiones pendientes de revisión
El usuario confirmó usar un atajo. Son propuestas del asistente la combinación Control + Opción + Z, la segunda pulsación para detener y revisar el texto antes de enviarlo.
