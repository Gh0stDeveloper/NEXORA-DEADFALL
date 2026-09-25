# NEXORA beta.8 — avance y recuperación

Actualizado: 2026-09-25. Base: main `5f08a0c01ed98387730523e34b5ec714dbcce0a7` (PR #18).
Rama: `agent/social-modes-beta8`. Primer checkpoint de implementación: `73a119882ee0e3206413956eccb9812f4ac544c7`.
Versión: `0.9.0-beta.8` / `900008`, mínimos cliente/servidor `900008`, protocolo 2 y contenido 2.

## Fases

- [x] A. Disparo sostenido con arrastre de cámara; recarga y cambio automático a arma utilizable.
- [x] B. Perfil visual, ID, amigos/búsqueda/solicitudes e historial por cuenta.
- [x] C. Selector ilustrado de seis modos, oleadas finitas/infinitas y PvP real.
- [x] D. Cola compatible, equipos incompletos, compañeros preservados y espera acotada.
- [ ] E. Verificación final, publicación y comprobación del PR.

## Comportamiento

- Un dedo dispara y mueve la cámara aunque salga del círculo. Otros dedos conservan joystick/acciones. Al cancelar/desactivar/perder foco se libera el disparo.
- Recarga al agotar el cargador. Si no queda reserva, se prefiere otra arma cargada, luego una con reserva; ambas agotadas seleccionan machete. La pistola repite el disparo táctil a su cadencia; con ratón conserva su comportamiento semiautomático.
- Perfil y listas con diseño NEXORA propio; personajes 3D, ID copiable, búsqueda por nombre/ID, solicitudes aceptadas/rechazadas y acceso al chat.
- Historial auténtico, últimas 100 partidas por cuenta. Estadísticas personales salen del servidor y sobreviven al reinicio. Las partidas todavía abiertas se guardan al finalizar, sin inventar entradas antiguas.
- Campaña normal, 10 oleadas, infinitas, todos contra todos, duelo de dúos y duelo interno entre compañeros.
- Cooperativo: misma misión/modo/formación, hasta 4 jugadores; llena plazas con quienes pulsaron iniciar. A los 8 s puede empezar incompleto, incluso un jugador en dúo/escuadra.
- PvP: hasta cuatro en FFA/duelo interno, o dos equipos de hasta dos; admite 1v1/2v1. Requiere oponente real; a los 30 s sin rival devuelve un mensaje y permite reintentar.
- PvP: daño autoritativo, sin daño al compañero, reaparición a 3 s y protección de 2 s; 10 bajas o 5 minutos. Resultado individual según equipo.
- El dedicado conserva lógica y colisiones, sin presentación. La cola/supervisión se consulta cada 250 ms.
- Formación conserva miembros y no permite encoger bajo el tamaño del grupo. Respuestas antiguas de sondeo no revierten un cambio pendiente.

## Evidencia local completada

Godot 4.6.3 oficial; la validación usa motor real y perfiles aislados.

- `gameplay_compile_smoke.gd`: pasa, con los nuevos gates de disparo/munición y social/modos, además de beta.7/login/HUD/lifecycle.
- `social_match_smoke.py`: pasa. API HTTP real crea un dúo y dos jugadores sueltos; los cuatro reciben tickets diferentes para el mismo dedicado y dos equipos 2v2. Clientes ENet reales disparan, observan recarga automática, consiguen diez bajas y reciben VICTORY/VICTORY/DEFEAT/DEFEAT. Historial de los cuatro correcto después de reiniciar el servicio y autenticarse nuevamente.
- `social_modes_smoke.gd`: límites de cola, dúo solitario, grupo incompleto, bloqueo de cambios al buscar, cancelación, búsqueda/solicitudes, reglas de daño, reaparición y referencias eliminadas al desconectar.
- `social_ui_smoke.sh`: pantalla renderizada y HTTP real para perfil, buscar/añadir amigo, aceptar solicitud, historial y seis modos. Capturas en `build/social-smoke/` usan cuentas de prueba.
- `presentation_runtime_smoke.sh`: arranque, registro inicial, recuperación de cuenta, lobby, partida, botines y regreso; pasa.
- `combat_smoke`, `horde_smoke`, `network_smoke`, `squad_smoke`, `campaign_smoke`, `beta_hardening_smoke`: pasan.
- `phase11_smoke`: pasa, incluido proceso dedicado real y reconexión por ticket.
- `server_navigation_smoke`: pasa. Quince interiores alcanzables y persecución ~1.8 m; servidor sin nodos de presentación.
- Portal Next.js e historial de versiones: `download_portal_smoke.sh` pasa; instalador VPS pasa.
- Pendiente final: repetir medición de carga cooperativa con cuatro clientes y publicar todos los cambios/verificar CI.

Las pruebas de reglas que se ejecutan en el updater aíslan su almacenamiento en memoria. La prueba HTTP/ENet usa directorio temporal y valida persistencia real. No deben escribir cuentas ficticias al almacenamiento del VPS.

## Límites externos y entrega

No se ha exportado un APK firmado ni probado en Android físico en este entorno; tampoco hay shell del VPS. Compilar con la firma existente e instalar sobre la versión anterior, conservando datos. La latencia de las pruebas es local; los 100–120 ms de beta.6 fueron reportados por el dueño.

GitHub Actions requiere `DEADFALL_MODELS_TOKEN` para leer el submódulo privado `Gh0stDeveloper/Objetos3D`. Beta.7 ya tenía ese bloqueo externo. No quitar gates de modelos para ocultarlo; comprobar el resultado real del nuevo PR.

El portal conserva `--keep-published-version` durante la exportación Android para que un catálogo beta.8 no invalide el APK beta.7 todavía publicado. El publicador final mantiene la comprobación estricta.

## Recuperar el trabajo

- Leer este documento y `CURRENT_STATUS.md`, consultar rama y PR antes de repetir cambios.
- Entorno local usado: `/workspace/scratch/dd56f684c4c7/NEXORA-DEADFALL`; Godot en `../tools/Godot_v4.6.3-stable_linux.x86_64`.
- Git local tiene ancestro sintético. Publicar árboles/commits sobre el SHA remoto real; nunca empujar esa historia local.
- Preservar gitlink `vendor/Objetos3D` en `28ea7a10a18fbe05a91fb3d920678991fff4afef` y los cuatro symlinks GLB.
- No excluir `scripts/build/` al filtrar el directorio raíz `build/`. No publicar `.godot`, imports, perfiles, tickets, dependencias ni APK sin verificar.
- `../tools/beta8-local-baseline.json` permite identificar cambios de esta fase; el estado local también muestra cambios viejos ya publicados.
