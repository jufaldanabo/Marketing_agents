---
name: telegram-approval
description: Envía un borrador a Telegram y hace polling de la respuesta del manager. Clasifica la intención (aprobado, editar, rechazado) y devuelve la decisión. Elimina la duplicación de aprobación entre publish-today, content-calendar, respond-comments, etc.
allowed-tools: [Bash, Read, Write]
model: claude-sonnet-4-6
---

# Skill: telegram-approval

**Propósito**: Flujo único de aprobación humana vía Telegram. Reemplaza las 5 duplicaciones que había en commands individuales. Lo invocan todos los agentes/commands que necesitan "preview + aprobar" antes de ejecutar una acción destructiva.

**Variables requeridas**: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

---

## Cuándo invocar

- Publisher antes de publicar post en IG/FB/TikTok
- Planner tras generar parrilla mensual
- Monitor antes de responder un comentario público
- Prospector antes de enviar outreach a lead
- Cualquier agente que requiera `human-in-the-loop`

## Cuándo NO invocar

- Notificaciones informativas sin requerir decisión → usar `telegram-notify`
- Flujos autónomos sin aprobación (operaciones internas, logs) → no usar Telegram

---

## Flujo

### Paso 1 — Preparar el borrador

El invocador pasa:
- `draft_id`: identificador único (ej. SHA1[:8] del contenido + timestamp)
- `preview_text`: contenido legible por humano, formato Telegram
- `preview_image_url` (opcional): URL de imagen preview
- `timeout_seconds`: cuánto esperar antes de dar timeout (default: 300)
- `poll_interval_seconds`: cada cuánto chequear respuestas (default: 15)
- `context`: breve descripción de qué se aprueba (ej. "Post Instagram - lunes")

### Paso 2 — Enviar preview a Telegram

```bash
TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Mensaje con draft_id al final para que el manager pueda referenciarlo
MESSAGE="🔍 APROBACIÓN REQUERIDA

Contexto: ${CONTEXT}
Draft ID: ${DRAFT_ID}

${PREVIEW_TEXT}

━━━━━━━━━━━━━━━━
Responde con:
  ✅ 'sí' / 'ok' / 'aprobar' / 'publicar' → aprobar
  ✏️ 'editar: {cambios}' → modificar
  ❌ 'no' / 'rechazar' / 'cancelar' → descartar"

# Si hay imagen, usar sendPhoto; si no, sendMessage
if [ -n "${PREVIEW_IMAGE_URL}" ]; then
  curl -s -X POST "${TELEGRAM_API}/sendPhoto" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "photo=${PREVIEW_IMAGE_URL}" \
    --data-urlencode "caption=${MESSAGE}"
else
  curl -s -X POST "${TELEGRAM_API}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}"
fi
```

Guardar `sent_at` para calcular timeout.

### Paso 3 — Cargar offset de Telegram

Leer `.claude/state/approvals/telegram-offset.json`:
```json
{"last_update_id": 123456789}
```

Si no existe, inicializar en 0 (procesará desde el primer mensaje disponible).

### Paso 4 — Hacer polling

Loop hasta `timeout_seconds`:

```bash
while [ $(date +%s) -lt $DEADLINE ]; do
  RESPONSE=$(curl -s "${TELEGRAM_API}/getUpdates?offset=${LAST_OFFSET}&limit=20&timeout=${POLL_INTERVAL}")

  # Procesar cada update
  # Buscar mensajes POSTERIORES a sent_at con texto o referencia a draft_id
  # Actualizar last_update_id al mayor procesado

  if [FOUND_DECISION]; then
    break
  fi

  sleep ${POLL_INTERVAL}
done
```

**Criterios de match**:
- Mensaje `text` incluye el `draft_id` (match más fuerte)
- O el mensaje es el PRIMERO del chat posterior a `sent_at` sin otro draft_id
- Ignorar mensajes del propio bot (`from.is_bot == true`)

### Paso 5 — Clasificar intención con haiku

Para cada candidate response, usar `claude-haiku-4-5` para clasificar:

```
System:
Clasifica la intención del mensaje humano en respuesta a una propuesta de contenido.

Opciones:
- "approve": aprobar y proceder (ej. "sí", "ok", "dale", "publicar", "aprobar", "👍")
- "edit": pide cambios específicos (ej. "cambiar X por Y", "más corto", "quita el emoji")
- "reject": rechaza y descarta (ej. "no", "cancelar", "mejor no", "rechazar")
- "unclear": no se puede determinar

Devuelve ÚNICAMENTE un JSON:
{"intent": "approve|edit|reject|unclear", "edit_instructions": "si edit, qué cambiar"}
```

Si `intent = "unclear"`, continuar polling (no decidir con ambigüedad).

### Paso 6 — Persistir decisión

Escribir en `.claude/state/approvals/pending/{draft_id}.json`:

```json
{
  "draft_id": "a1b2c3d4",
  "context": "Post Instagram - lunes",
  "sent_at": "2026-03-15T10:00:00Z",
  "decided_at": "2026-03-15T10:03:42Z",
  "decision": "approve|edit|reject|timeout",
  "edit_instructions": "...",
  "manager_message": "mensaje original del manager",
  "manager_user_id": 123456
}
```

Actualizar `telegram-offset.json` con el `last_update_id`.

### Paso 7 — Devolver al invocador

```json
{
  "ok": true,
  "decision": "approve",
  "draft_id": "a1b2c3d4",
  "elapsed_seconds": 222,
  "edit_instructions": null,
  "manager_message": "sí, publicar"
}
```

En caso de timeout:
```json
{
  "ok": false,
  "decision": "timeout",
  "draft_id": "a1b2c3d4",
  "elapsed_seconds": 300,
  "suggestion": "Usa /check-approvals cuando el manager responda, o re-ejecuta el command"
}
```

---

## Semánticas por decisión

| Decisión | Qué hace el invocador |
|---|---|
| `approve` | Procede con la acción |
| `edit` | Re-genera incorporando `edit_instructions`, vuelve a invocar `telegram-approval` con nuevo `draft_id` |
| `reject` | Aborta la acción. Marca el draft como descartado |
| `timeout` | Deja el draft en pending. `/check-approvals` lo recoge luego |

---

## Idempotencia

- Si el mismo `draft_id` ya tiene decisión persistida en `pending/{draft_id}.json`, devolver esa decisión sin re-enviar a Telegram.
- Esto permite que un command se re-ejecute y recoja la decisión previa sin spam.

---

## Reglas de UX

1. **Preview completo**: El manager debe ver TODO el contenido (texto + imagen) antes de aprobar.
2. **Formato legible**: Usar emojis para separar secciones. Preview no debe superar 4096 chars (límite Telegram).
3. **Draft ID visible**: Siempre al final del preview para que el manager pueda referenciarlo.
4. **No bloquear infinito**: Timeout es obligatorio. 5min default, override por invocador.

---

## Notas

- Este skill **centraliza** la lógica que estaba duplicada en 5 commands.
- El invocador no necesita conocer la API de Telegram ni el formato de updates.
- La clasificación con haiku es más robusta que regex (acepta variaciones naturales).
- El offset persiste entre runs — nunca se procesa un mensaje 2 veces.
