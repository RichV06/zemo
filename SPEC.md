# Zemo

## Objetivo
Una app nativa para macOS: un boyero australiano astronauta flotante abre un chat en español que comunica instrucciones en lenguaje natural a Codex CLI y muestra su actividad de terminal.

## Alcance y criterios de aceptación
- Mascota transparente, arrastrable y visible sobre otras ventanas; clic abre/cierra el chat.
- Arte original pixelado (busto de 64×64 con casco de astronauta) de un blue heeler adulto, proporciones sobrias y ojos pequeños; estados y animación de respiración y reacción al trabajo, compatible con movimiento reducido. Se genera con `tools/sprites/build.py` hacia `Assets/sprites/` (cambio del 24 de octubre: reemplaza el arte de cuerpo completo de cuatro patas).
- Chat accesible por teclado, estado de conexión, selector de carpeta, salida de comandos y respuesta final.
- Consulta por defecto (sandbox read-only); cambios únicamente al elegir explícitamente el modo de edición para una carpeta de proyecto. Sin permisos elevados ni bypass del sandbox.
- Entrada por stdin y argumentos separados; nunca interpolar mensajes en un shell.
- Una tarea a la vez; detener termina el árbol de procesos. Errores de conexión, sesión y ejecutable ausente aparecen en el chat.
- Contexto de conversación en memoria; limpiar chat y cambiar carpeta reinicia contexto. Sin guardar conversaciones en la app.
- App autocontenida sin dependencias externas de Swift; usa la sesión existente de Codex, cuyo uso está sujeto al plan y conectividad del usuario.

## Stack y estructura
Swift 6, SwiftUI y AppKit. macOS 14+. `Sources/AstroCore`: protocolo y ejecución. `Sources/AstroBoyero`: interfaz y ventanas. `Tests/AstroCoreTests`: validación, eventos y procesos. `Assets`: arte. `scripts`: empaquetado.

## Comandos
Pruebas: `swift run --disable-sandbox AstroCoreChecks` (suite Foundation; XCTest no está incluido en estas Command Line Tools). Compilar y empaquetar: `bash scripts/build-app.sh`. Abrir: `open dist/Zemo.app`.

## Estilo
Swift con cuatro espacios, tipos UpperCamelCase, métodos lowerCamelCase. Ejemplo: `guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RequestError.emptyPrompt }`.

## Verificación
Pruebas del límite de permisos, entradas vacías y grandes, streaming JSON con fragmentación UTF-8, resultados y errores. Pruebas con procesos reales controlados para stdout/stderr y cancelación; compilación release y revisión visual en macOS. Prueba real de consulta a Codex si la conectividad lo permite.

## Límites y riesgos
Siempre respetar el sandbox de Codex, las instrucciones de cada carpeta y la configuración de autenticación existente. Nunca registrar credenciales ni usar acceso completo. Pedir confirmación dentro de la app al habilitar edición; esto permite cambios en la carpeta elegida y no garantiza deshacerlos. La app no puede convertir prompts en comandos sin un modelo disponible. No instala servicios ni se inicia al arrancar.

## Plan de ejecución
1. Probar y construir el adaptador de eventos y la solicitud segura.
2. Probar y construir streaming, salida de error, cancelación y descubrimiento de Codex.
3. Integrar mascota, chat, controles de carpeta y modo.
4. Empaquetar, ejecutar pruebas, revisar interfaz y abrir la app.
