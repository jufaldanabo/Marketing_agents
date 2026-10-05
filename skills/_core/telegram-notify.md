---
name: telegram-notify
description: Envía notificaciones a Telegram sin requerir respuesta del usuario. Usado para alertas, reportes y confirmaciones de operaciones autónomas. Soporta split automático para mensajes largos.
allowed-tools: [Bash]
model: claude-haiku-4-5
---

# Skill: telegram-notify

**Propósito**: Envío unidireccional de mensajes a Telegram (fire-and-forget). Diferente de `telegram-approval` que espera respuesta.

**Variables requeridas**: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

---

## Cuándo invocar

- Reporte nocturno de `social-monitor`
- Alerta de token por vencer
- Confirmación "post publicado" tras publisher exitoso
- Alerta de crisis detectada
- Reporte de inteligencia de mercado
- Notificación de lead que respondió positivamente

## Cuándo NO invocar

- Si se necesita decisión del manager → usar `telegram-approval`
- Para enviar imágenes → usar `telegram-notify` con `photo_url` o `telegram-approval` si requiere aprobación

---

## Flujo

### Paso 1 — Validar inputs

- `message` (string, obligatorio): texto a enviar
- `photo_url` (string, opcional): URL o path local de imagen a adjuntar
- `priority` (enum: `low`, `normal`, `high`, default `normal`): afecta el prefijo
- `parse_mode` (enum: `Markdown`, `HTML`, `plain`, default `Markdown`): formato Telegram

### Paso 2 — Preparar mensaje

Agregar prefijo según `priority`:

| Priority | Prefijo |
|---|---|
| `low` | `ℹ️ ` |
| `normal` | (ninguno) |
| `high` | `🚨 ALERTA — ` |

### Paso 3 — Dividir si supera 4096 caracteres

Telegram tiene límite de 4096 caracteres por mensaje. Si `message.length > 4000`:

1. Split en chunks de ~3900 chars respetando saltos de línea
2. Agregar `(1/N)`, `(2/N)` al final de cada chunk
3. Enviar en secuencia con 500ms entre envíos

### Paso 4 — Enviar

**Mensaje sin imagen:**
```bash
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "parse_mode=${PARSE_MODE}" \
  --data-urlencode "text=${MESSAGE}"
```

**Mensaje con imagen (URL remota):**
```bash
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "photo=${PHOTO_URL}" \
  -d "parse_mode=${PARSE_MODE}" \
  --data-urlencode "caption=${MESSAGE}"
```

**Mensaje con imagen (archivo local):**
```bash
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
  -F "chat_id=${TELEGRAM_CHAT_ID}" \
  -F "photo=@${PHOTO_PATH}" \
  -F "parse_mode=${PARSE_MODE}" \
  -F "caption=${MESSAGE}"
```

### Paso 5 — Manejo de errores

Si la respuesta de Telegram es `{"ok": false, ...}`:

| Error code | Causa | Acción |
|---|---|---|
| `401` | Token inválido | Fallar con mensaje claro, sugerir `/setup-check` |
| `400` + "chat not found" | TELEGRAM_CHAT_ID inválido | Fallar y sugerir re-configurar |
| `429` | Rate limit | Leer `retry_after` del response, esperar, reintentar hasta 3 veces |
| `413` | Payload demasiado grande (foto) | Reducir tamaño o fallar |
| Otros | Error desconocido | Loggar y devolver `{"ok": false, "error": "..."}`

### Paso 6 — Loggar

Invocar `state-store append-log`:
```json
{
  "level": "info",
  "event": "telegram_notify_sent",
  "priority": "normal",
  "message_length": 342,
  "has_photo": false
}
```

### Paso 7 — Devolver al invocador

```json
{
  "ok": true,
  "message_id": 12345,
  "parts_sent": 1
}
```

---

## Formato recomendado para notificaciones

### Reporte nocturno
```
📊 REPORTE NOCTURNO — {FECHA}

Resumen:
• X comentarios nuevos (Y requieren respuesta)
• Z mensajes directos
• W menciones

Métricas 7d:
• Alcance: ...
• Engagement: ...

Top post: {TÍTULO} ({ENGAGEMENT})
```

### Alerta de crisis
```
🚨 ALERTA — Comentario crítico detectado

Plataforma: Instagram
Post: {URL}
Comentario: "{SNIPPET}"

Severidad: alta
Sugerencia: Revisar y responder en <2h
```

### Confirmación post publicado
```
✅ Post publicado

Plataforma: Instagram
URL: {POST_URL}
Hora: {TIMESTAMP}

Visible aquí: {LINK}
```

---

## Notas

- Fire-and-forget: no espera decisión del usuario.
- Si Telegram no responde en 10s, fallar y loggar (no bloquear al invocador).
- Usar `parse_mode=Markdown` por defecto para que `*negrita*` y `_itálica_` funcionen.
- Si el mensaje incluye `` ` `` o `*` sin escapar, usar `parse_mode=plain` para evitar errores.
