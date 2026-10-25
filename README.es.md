# Zemo 🐕🚀

Un boyero australiano astronauta que vive en tu escritorio y abre un chat conectado a Codex, Claude o Gemini (sus CLIs). App nativa para macOS 14 o superior, en español, con arte original pixelado transparente y animación sutil.

## Abrir

Abre `dist/Zemo.app` con doble clic. También:

```bash
open "dist/Zemo.app"
```

Haz clic en el perrito para abrir u ocultar el chat. Arrástralo para moverlo. El menú de la huella en la barra superior permite recuperar el chat, ocultar la mascota o salir. Cerrar el chat conserva la mascota; Cmd+Q sale de la app.

Selecciona una carpeta y escribe, por ejemplo: «¿Qué hay en esta carpeta?» o «Revisa el estado de Git». La vista de terminal muestra los comandos y su salida cuando Codex publica los eventos. Usa el botón cuadrado para detener la tarea. Enter envía; el campo admite varias líneas. Los mensajes tienen un botón para copiar.

## Permisos y datos

- **Consultar** es el modo inicial: Codex utiliza `read-only`.
- **Editar carpeta** requiere confirmación y usa `workspace-write`. Elige una carpeta de proyecto concreta. Cambiar de carpeta vuelve a consulta y limpia la conversación.
- La app no pasa tu texto a un shell: lo envía por stdin a Codex con argumentos separados. No activa acceso completo ni eleva permisos. Codex recibe `approval_policy="never"`; una operación que requiera aprobación no se autoriza automáticamente.
- Se ignora la configuración de usuario de Codex para evitar heredar plugins, hooks o permisos personalizados. Se utiliza la autenticación existente y el modelo predeterminado del CLI; no hay selector de modelo en esta versión.
- La carpeta indica dónde trabajar y dónde se permiten cambios; el sandbox de Codex no promete restringir toda lectura a esa carpeta.
- La app conserva la conversación en memoria y utiliza sesiones efímeras de Codex. Los mensajes y el contexto se envían al servicio de IA mediante tu sesión. Siguen aplicando las políticas de datos de tu cuenta y los posibles registros operativos del CLI. La app no guarda credenciales ni crea un historial propio en disco.
- Detener finaliza el grupo de procesos con SIGTERM y, si hace falta, SIGKILL. Hay un límite de 15 minutos por tarea. **No revierte cambios ya realizados.**
- El historial enviado al modelo se limita a los últimos doce mensajes. Para eliminar el contexto, usa Nueva conversación.

## Motores: Codex, Claude y Gemini

El menú **Motor** del chat elige quién procesa tus instrucciones; se recuerda entre sesiones y no se puede cambiar durante una tarea o un dictado. Cada motor usa su propio CLI y su propia sesión (`codex login`, `claude`, `gemini`), y tu texto se envía a su proveedor (OpenAI, Anthropic o Google), que el chat muestra siempre.

| | Codex | Claude | Gemini |
|---|---|---|---|
| Consultar | sandbox `read-only` | modo `plan`: lee archivos y solo comandos de lectura (git, ls, cat, rg, gh de lectura) | modo `plan` (sin terminal) |
| Editar carpeta | sandbox `workspace-write` | crea y edita archivos; `rm`, `mv` y demás comandos piden aprobación y se rechazan | modo `auto_edit` (sin terminal) |
| Notion | conector MCP de lectura | conector de tu cuenta, solo búsqueda y lectura | no disponible |
| GitHub | conector MCP de lectura | `gh` de lectura | no disponible |
| Drive | carpeta local | carpeta local y lectura por conector | carpeta local |

Ningún motor usa `--yolo`, `bypassPermissions` ni acceso total. Cada proceso recibe solo las variables de entorno de su propio proveedor. Claude carga tu configuración de usuario (necesaria para ver tus conectores de cuenta); si algún día añades reglas de permiso permisivas en `~/.claude/settings.json`, afectarían a Zemo.

## Voz

Pulsa **Control + Opción + Z** (desde cualquier app, con Zemo abierto) o el botón del micrófono: Zemo muestra el chat y escucha. Vuelve a pulsar para terminar; el texto queda en el borrador para que lo revises y lo envíes tú con Enter. **Esc** o la X cancelan y conservan lo que ya tenías escrito.

- Reconocimiento local de macOS en español; no se usa ningún servicio de transcripción. Si el Mac no tiene el reconocimiento local, Zemo lo dice y no envía audio a ningún otro lado.
- Máximo 60 segundos por dictado. No hay escucha continua ni palabra de activación. No se guarda audio ni texto en disco.
- No se puede dictar mientras corre una tarea, ni cambiar de carpeta, modo o conversación mientras se graba.
- Los permisos de micrófono y reconocimiento se piden al primer uso. Si los niegas, el chat escrito sigue funcionando. Al ser una firma ad hoc, macOS puede volver a pedirlos tras reconstruir la app.
- Si otro programa ocupa el atajo, Zemo lo avisa y el botón sigue disponible.

## Notion, GitHub y Google Drive

Zemo accede a los tres **solo en lectura**, en ambos modos:

- **Notion** y **GitHub**: conectores MCP remotos (`notion-search`/`notion-fetch`, y el endpoint `/readonly` de GitHub). Inicia sesión una vez con `bash scripts/connect-services.sh` (abre el navegador para autorizar).
- **Google Drive**: lee la carpeta local sincronizada `~/Google Drive/My Drive`; no necesita sesión adicional.

Sin sesión iniciada, Zemo avisa que el conector no está disponible. El texto de tus páginas y repos pasa al servicio de IA como cualquier otro contexto.

## Requisitos

Codex CLI instalado y con sesión iniciada (`codex login`). Se busca en `~/.local/bin`, Homebrew, PATH y las instalaciones de Node de NVM. Se requiere conectividad con el servicio de IA y disponibilidad en tu cuenta. No necesitas otra clave API.

Si falla una tarea, comprueba en Terminal:

```bash
codex --version
codex login status
```

## Desarrollo y validación

Sin paquetes de terceros: SwiftUI, AppKit y Foundation incluidos en macOS.

```bash
# Pruebas de protocolo, permisos, streaming, procesos y cancelación
swift run --disable-sandbox AstroCoreChecks

# App release con icono y firma ad hoc para uso local
bash scripts/build-app.sh
```

Las Command Line Tools de este Mac no contienen XCTest. `AstroCoreChecks` ejecuta la suite con Foundation sin descargar dependencias. `--disable-sandbox` se aplica al proceso de construcción de SwiftPM para permitir compilar dentro del entorno administrado; no modifica el sandbox de las tareas de Codex.

El paquete se firma ad hoc para uso local. Para distribuirlo a otras personas habría que firmarlo con Developer ID y notarizarlo.

## Estructura

- `Sources/AstroCore`: validación, argumentos, eventos JSONL, streams y grupos de procesos.
- `Sources/AstroBoyero`: ventanas nativas, chat, mascota, permisos y estado.
- `Tests/AstroCoreTests`: suite ejecutable sin dependencias.
- `Assets/zemo.png`: arte original generado para este proyecto.
- `scripts/build-app.sh`: compilación y empaquetado.
- `SPEC.md`: alcance y criterios de aceptación.

Referencias oficiales: [Codex no interactivo](https://learn.chatgpt.com/docs/non-interactive-mode) y [seguridad de Codex](https://learn.chatgpt.com/docs/security). Los argumentos utilizados se contrastaron con `codex exec --help` de la versión instalada.
