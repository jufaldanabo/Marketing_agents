# Skill: content-approval

**Propósito**: Guarda un borrador de contenido como "pendiente de aprobación",
lo envía al manager via Telegram para revisión, y registra el draft_id
para que `/check-approvals` pueda publicarlo cuando llegue la aprobación.
**Modelo**: No requiere Claude
**Usado por**: `/publish-today` (modo con aprobación)

---

## Cuándo usar este skill

Cuando se quiere que un humano revise el contenido antes de publicar.
En lugar de publicar inmediatamente, el agente:
1. Guarda el borrador
2. Notifica al manager por Telegram con preview
3. El manager responde en Telegram: `aprobar`, `editar:` o `rechazar`
4. El comando `/check-approvals` recoge esa respuesta y actúa

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `content` | dict | El contenido generado (instagram, facebook, tiktok según aplique) |
| `platforms` | list | Qué plataformas incluye el borrador |
| `topic` | string | Tema del contenido (para contexto en Telegram) |
| `image_description` | string | Descripción de la imagen sugerida |

## Paso 1 — Generar ID único del borrador

```
draft_id = primeros 8 caracteres del SHA1 de (TIMESTAMP + TOPIC)
Ejemplo: draft_id = "a3f9c21b"
```

El draft_id se incluye en el mensaje de Telegram para que el manager pueda referenciarlo.

## Paso 2 — Guardar el borrador en disco

Guardar en `.claude/drafts/{draft_id}.json`:

```json
{
  "draft_id": "a3f9c21b",
  "status": "pending_approval",
  "topic": "{TOPIC}",
  "platforms": ["instagram", "facebook", "tiktok"],
  "created_at": "{TIMESTAMP_ISO}",
  "approved_at": null,
  "published_at": null,
  "telegram_message_id": null,
  "content": {
    "instagram": {
      "caption": "...",
      "hashtags": ["..."],
      "suggested_image": "..."
    },
    "facebook": {
      "message": "...",
      "cta": "..."
    },
    "tiktok": {
      "description": "...",
      "hashtags": ["..."],
      "video_script": "...",
      "photo_caption": "..."
    }
  },
  "image_description": "{IMAGE_DESCRIPTION}",
  "rejection_reason": null,
  "edit_instructions": null
}
```

## Paso 3 — Construir el mensaje de Telegram

El mensaje debe ser claro, fácil de leer en móvil, y con instrucciones de respuesta obvias.

### Formato del mensaje de Telegram

```
📝 *BORRADOR #{DRAFT_ID} listo para revisión*
📅 {FECHA} | 🏢 {COMPANY_NAME}
Tema: _{TOPIC}_

{SI INSTAGRAM EN PLATAFORMAS}
━━━ 📸 INSTAGRAM ━━━
{PRIMERAS 200 CHARS DEL CAPTION}...
_Hashtags: {PRIMEROS 5 HASHTAGS}_

{SI FACEBOOK EN PLATAFORMAS}
━━━ 👥 FACEBOOK ━━━
{PRIMERAS 200 CHARS DEL MESSAGE}...

{SI TIKTOK EN PLATAFORMAS}
━━━ 🎵 TIKTOK ━━━
{SI VIDEO: "📹 Video: " + PRIMERAS 150 CHARS DEL SCRIPT}
{SI FOTO: "🖼 Foto: " + CAPTION}

🖼 _Imagen sugerida: {IMAGE_DESCRIPTION}_

━━━━━━━━━━━━━━━━━━━━
Para aprobar, escribe en este chat:
✅ `aprobar {DRAFT_ID}`
✍️ `editar {DRAFT_ID}: [describe los cambios]`
❌ `rechazar {DRAFT_ID}: [motivo]`
```

### Enviar a Telegram

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "{MENSAJE_FORMATEADO}",
  "parse_mode": "Markdown"
}
```

Guardar el `message_id` de la respuesta en el draft (`telegram_message_id`).

## Paso 4 — Actualizar el archivo de estado del polling

Para que `/check-approvals` sepa desde qué update_id de Telegram leer:

Leer `.claude/drafts/_telegram_offset.json` (si no existe, crearlo con `{"offset": 0}`).
No modificar el offset aquí — solo `/check-approvals` lo actualiza.

## Output del skill

```json
{
  "draft_id": "a3f9c21b",
  "status": "pending_approval",
  "telegram_sent": true,
  "telegram_message_id": 842,
  "saved_to": ".claude/drafts/a3f9c21b.json",
  "message": "Borrador enviado para aprobación. Usa /check-approvals para publicar cuando se apruebe."
}
```

## Estructura de `.claude/drafts/`

```
.claude/drafts/
├── a3f9c21b.json          ← borrador pendiente
├── b7d2e45f.json          ← borrador aprobado y publicado
├── c9a1f823.json          ← borrador rechazado
└── _telegram_offset.json  ← último update_id procesado por check-approvals
```

## Notas

- Un borrador pendiente no expira automáticamente — el manager puede aprobar días después
- Si hay más de 5 borradores pendientes, incluir aviso en el mensaje de Telegram
- Los borradores publicados o rechazados se mantienen por 30 días para historial
- El manager debe estar en el mismo chat (`TELEGRAM_CHAT_ID`) donde el bot envía mensajes
- Para grupos: el manager puede responder al mensaje del bot con "aprobar a3f9c21b"
