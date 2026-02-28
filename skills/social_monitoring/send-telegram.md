# Skill: send-telegram

**Propósito**: Envía mensajes y reportes por Telegram Bot API.
**API**: Telegram Bot API
**Usado por**: `monitoring-agent.md`, `intelligence-agent.md`, `/social-report`, `/market-intel`

---

## Cuándo usar este skill

Usar para enviar notificaciones, alertas o reportes al equipo vía Telegram.
Es el canal de notificación principal del toolkit.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `message` | string | Texto del mensaje (soporta Markdown) |
| `TELEGRAM_BOT_TOKEN` | env | Token del bot (obtener con @BotFather) |
| `TELEGRAM_CHAT_ID` | env | ID del chat, grupo o canal destino |
| `parse_mode` | string | "Markdown" o "HTML" (por defecto: Markdown) |

## Enviar mensaje de texto

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage

Body (JSON):
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "{MENSAJE}",
  "parse_mode": "Markdown"
}

Respuesta exitosa:
{
  "ok": true,
  "result": {
    "message_id": 42,
    "chat": { "id": -1001234567890 },
    "date": 1735689600,
    "text": "..."
  }
}
```

## Formato Markdown soportado por Telegram

```markdown
*texto en negrita*
_texto en cursiva_
`código inline`
```bloque de código```
[texto del enlace](https://url.com)
```

## Plantillas de mensajes del toolkit

### Alerta urgente
```
🚨 *ALERTA — {EMPRESA}*

{DESCRIPCION_DEL_PROBLEMA}

⏰ Detectado: {HORA}
📱 Plataforma: {INSTAGRAM/FACEBOOK}
🔗 [Ver comentario]({URL})

Acción requerida en menos de {SLA}.
```

### Reporte nocturno (resumen)
```
🌙 *REPORTE NOCTURNO — {EMPRESA}*
📅 {FECHA} | {HORA}

📊 *Métricas del día:*
• IG Alcance: {REACH} | Likes: {LIKES}
• FB Alcance: {REACH} | Interacciones: {ENG}

💬 *Comentarios pendientes: {N}*
{LISTA_TOP_3}

⚠️ *Alertas: {N_ALERTAS}*
{DESCRIPCION_ALERTAS}

✅ *Para mañana:*
{TOP_3_ACCIONES}

_Reporte completo en .claude/reports/_
```

### Confirmación de publicación
```
✅ *POST PUBLICADO — {EMPRESA}*
📅 {FECHA} | {HORA}

📸 Instagram: {OK/PENDIENTE}
📘 Facebook: {OK/PENDIENTE}

📝 Tema: {TOPIC}
🔗 [Ver en Instagram]({URL_IG})
🔗 [Ver en Facebook]({URL_FB})
```

### Informe de inteligencia (resumen ejecutivo)
```
📊 *INTELIGENCIA DE MERCADO — {EMPRESA}*
📅 Semana del {FECHA}

🎯 *Resumen:*
{RESUMEN_EJECUTIVO_2_LINEAS}

💰 *Precios destacados:*
{TOP_3_COMMODITIES_CON_VARIACION}

🏢 *Competidores:*
{TOP_2_MOVIMIENTOS_RELEVANTES}

🔴 *Riesgo principal:* {RIESGO}
🟢 *Oportunidad:* {OPORTUNIDAD}

_Informe completo en .claude/intel/_
```

## Enviar archivo (documento)

```
POST https://api.telegram.org/bot{TOKEN}/sendDocument

Body (multipart/form-data):
  chat_id   = {CHAT_ID}
  document  = @{RUTA_AL_ARCHIVO}
  caption   = "Reporte completo — {FECHA}"
```

## Obtener el Chat ID

Si no conoces el chat_id del grupo o canal:
1. Agregar el bot al grupo
2. Enviar un mensaje en el grupo
3. Llamar: `GET https://api.telegram.org/bot{TOKEN}/getUpdates`
4. Buscar `"chat": {"id": ...}` en la respuesta

## Manejo de errores

| Error | Descripción | Solución |
|---|---|---|
| 401 Unauthorized | Token inválido | Verificar token con @BotFather |
| 400 Bad Request | Chat no encontrado | Verificar chat_id; el bot debe ser miembro |
| 429 Too Many Requests | Rate limit | Esperar `retry_after` segundos |
| Mensaje muy largo | Máx 4,096 caracteres | Dividir en múltiples mensajes |

## Límites de Telegram Bot API

- Máximo 4,096 caracteres por mensaje de texto
- Máximo 50 MB por archivo enviado
- Rate limit: 30 mensajes por segundo (por bot)
- Para grupos grandes: 20 mensajes por minuto
