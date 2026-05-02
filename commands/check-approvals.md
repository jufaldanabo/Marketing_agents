# Command: /check-approvals

**Propósito**: Revisa el chat de Telegram en busca de respuestas del manager
a borradores pendientes de aprobación. Publica los aprobados, regenera los que
piden edición, y marca como rechazados los que no pasaron.
**Modelo**: `claude-opus-4-6` (solo para regenerar contenido cuando hay ediciones)
**Skills usados**: `content-approval.md`, `publish-instagram.md`, `publish-facebook.md`, `publish-tiktok.md`

---

## Cuándo ejecutar

| Momento | Cómo |
|---|---|
| Programado cada 30 min en Railway | Cron: `*/30 * * * *` |
| Manualmente desde Claude Code | `/check-approvals` |
| Después de que el manager dice que aprobó | `/check-approvals --now` |

---

## Flujo de ejecución

### Paso 0 — Cargar variables de entorno

```bash
# Local: carga .env si existe | Railway: no-op (vars ya en entorno)
[ -f .env ] && export $(grep -v '^#' .env | xargs)
```

---

### Paso 1 — Leer borradores pendientes

Leer todos los archivos de `.claude/drafts/` donde `status == "pending_approval"`.

Si no hay borradores pendientes → terminar con mensaje: `✅ No hay borradores pendientes.`

### Paso 2 — Consultar Telegram por respuestas nuevas

Leer el offset actual desde `.claude/drafts/_telegram_offset.json`.

```
GET https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getUpdates
  ?offset={OFFSET_ACTUAL}
  &limit=100
  &timeout=0
```

Esto devuelve todos los mensajes recibidos por el bot desde el último offset.

### Paso 3 — Parsear respuestas del manager

Para cada mensaje recibido, clasificar la intención en lenguaje natural (case insensitive).

**Aprobación** — el mensaje es una afirmación o aprobación:
- Con draft_id: `aprobar {DRAFT_ID}`, `apruebo {DRAFT_ID}`
- Sin draft_id (solo si hay **un único** borrador pendiente):
  `sí`, `si`, `ok`, `dale`, `va`, `listo`, `aprobado`, `publícalo`,
  `publicar`, `adelante`, `perfecto`, `está bien`, `sale`
- Ejemplo: "aprobar a3f9c21b", "sí", "dale", "ok"
- Acción: publicar el borrador en todas sus plataformas
- Si hay múltiples borradores pendientes y no se especifica draft_id,
  responder en Telegram: `🤔 Tienes {N} borradores pendientes. Especifica cuál: aprobar {DRAFT_ID}`

**Edición:**
- Con draft_id: `editar {DRAFT_ID}: {INSTRUCCIONES}`
- Sin draft_id (solo si hay un único borrador pendiente):
  cualquier mensaje que pida cambios al contenido
  (ej. "ponle otro tono", "quita el precio", "hazlo más corto")
- Ejemplo: "editar a3f9c21b: cambiar el tono a más informal", "hazlo más corto"
- Acción: regenerar el contenido con las instrucciones y enviar nuevo borrador para aprobación

**Rechazo** — el mensaje es una negación clara:
- Con draft_id: `rechazar {DRAFT_ID}` o `rechazar {DRAFT_ID}: {MOTIVO}`
- Sin draft_id (solo si hay un único borrador pendiente):
  `no`, `rechazar`, `cancelar`, `no publicar`, `descarta`, `mejor no`
- Ejemplo: "rechazar a3f9c21b: no es el momento", "no", "mejor no"
- Acción: marcar como rechazado y guardar el motivo

**Actualizar offset:**
Después de procesar todos los mensajes, actualizar `_telegram_offset.json`
con el `update_id` más alto + 1.

### Paso 4 — Ejecutar la acción correspondiente

#### Si es APROBACIÓN:

Para cada plataforma en `draft.platforms`:

**Instagram:** ejecutar `publish-instagram.md` con los datos del borrador
**Facebook:** ejecutar `publish-facebook.md` con los datos del borrador
**TikTok:** ejecutar `publish-tiktok.md` con los datos del borrador
  - Si es video y no hay archivo en `.claude/pending-videos/` → publicar foto en su lugar + notificar

Actualizar el borrador: `status = "published"`, `published_at = NOW`.

Enviar confirmación por Telegram:
```
POST https://api.telegram.org/bot{TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "✅ Borrador #{DRAFT_ID} publicado con éxito\n📱 {PLATAFORMAS}\n📅 {FECHA Y HORA}"
}
```

#### Si es EDICIÓN:

Regenerar el contenido usando `claude-opus-4-6`:

```
SYSTEM:
Eres un asistente de marketing. Tienes el borrador original y unas instrucciones
de edición del manager. Genera el contenido corregido manteniendo el tema pero
aplicando exactamente los cambios solicitados.

USER:
Borrador original:
{CONTENIDO_ORIGINAL_DEL_DRAFT}

Instrucciones de edición:
{INSTRUCCIONES_DEL_MANAGER}

Genera el contenido corregido en el mismo formato JSON.
```

Guardar el nuevo borrador (nuevo `draft_id`) y ejecutar `content-approval.md` para
enviarlo de nuevo para aprobación.

Notificar en Telegram:
```
✍️ Borrador #{DRAFT_ID_ORIGINAL} editado
Nuevo borrador: #{NUEVO_DRAFT_ID}
Cambios aplicados: {INSTRUCCIONES}
👆 Revisa arriba el nuevo borrador
```

#### Si es RECHAZO:

Actualizar el borrador: `status = "rejected"`, `rejection_reason = MOTIVO`.

Notificar en Telegram:
```
❌ Borrador #{DRAFT_ID} marcado como rechazado
Motivo: {MOTIVO}
```

### Paso 5 — Reporte del ciclo

Si hubo actividad, mostrar resumen en consola:

```
## /check-approvals — {TIMESTAMP}

Borradores revisados: {N}
✅ Publicados: {N}   → {LISTA_DRAFT_IDS}
✍️ Editados:   {N}   → {LISTA_DRAFT_IDS} (nuevos borradores enviados)
❌ Rechazados: {N}   → {LISTA_DRAFT_IDS}
⏳ Sin respuesta: {N} → {LISTA_DRAFT_IDS} (pendientes desde hace {HORAS}h)
```

Si hay borradores sin respuesta hace más de **48 horas**, enviar recordatorio por Telegram:
```
⏰ Recordatorio: tienes {N} borrador(es) esperando aprobación
El más antiguo lleva {HORAS}h esperando.
Responde en este chat: aprobar / editar / rechazar
```

---

## Opciones del command

```bash
/check-approvals              # Verificar y procesar respuestas pendientes
/check-approvals --list       # Solo listar borradores pendientes sin procesar Telegram
/check-approvals --force {ID} # Forzar publicación de un borrador específico sin aprobación
/check-approvals --clear      # Marcar todos los borradores viejos (+7 días) como expirados
```

---

## Casos edge

**Si el manager responde sobre un draft_id que no existe:**
Ignorar el mensaje y no actualizar el offset (para no perder mensajes futuros).

**Si falla la publicación después de aprobar:**
Marcar el borrador con `status = "publish_failed"`, notificar por Telegram con el error,
y mantener el draft disponible para reintentar con `/check-approvals --force {ID}`.

**Si el bot no ha recibido ningún mensaje (getUpdates vacío):**
Normal — no hay respuestas aún. Terminar silenciosamente si está en modo Railway.

---

## Configuración en railway.toml

```toml
[[services]]
name = "check-approvals"
startCommand = "python deploy/scheduler.py check-approvals"

[services.deploy]
cronSchedule = "*/30 * * * *"
```

Esto verifica aprobaciones cada 30 minutos. Ajustar según necesidad.
