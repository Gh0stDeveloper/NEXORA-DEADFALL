# NEXORA: ampliación social y modos — avance persistente

Base verificada: main `5f08a0c01ed98387730523e34b5ec714dbcce0a7` (beta.7 / PR #18).

## Fases
- [ ] A. Disparo sostenido con arrastre para apuntar; recarga y selección automática con munición.
- [ ] B. Perfil visual, ID público, amigos/búsqueda/solicitudes e historial real persistente.
- [ ] C. Selector de campaña, oleadas finitas/infinita y enfrentamientos PvP.
- [ ] D. Cola compatible por modo y tamaño, grupos incompletos y espera acotada sin jugadores ficticios.
- [ ] E. Validación de controles, autoridad/daño, estados de partida, UI renderizada y publicación.

## Criterios
- Diseño propio NEXORA tomando distribución de las capturas del usuario.
- Disparo/cámara simultáneos con un dedo, joystick independiente, liberar al cancelar o perder foco.
- Servidor conserva autoridad de munición, daño, resultados y matchmaking; sin presentación 3D.
- Emparejar solamente grupos que pulsaron iniciar en el mismo modo. Mantener juntos grupos existentes.
- Máximo actual por instancia: cuatro jugadores. PvP todos contra todos o dos equipos (máximo dos por equipo).
- Partidas cooperativas pueden empezar sin completar grupo después de una espera corta; PvP requiere un rival real.
- No inventar historial/estadísticas. Resultados de servidor persistentes por cuenta.

## Entorno y límites conocidos
Godot 4.6.3 disponible en ../tools. Sin Android físico, SDK/firma ni acceso shell al VPS.
Git local tiene ancestro sintético: publicar mediante árbol/commit de GitHub sobre SHA remoto real, nunca empujar esta historia local.
No perder gitlink vendor/Objetos3D ni symlinks GLB. CI Android/Godot necesita el secreto DEADFALL_MODELS_TOKEN para submódulo privado (pendiente externo de beta.7).
