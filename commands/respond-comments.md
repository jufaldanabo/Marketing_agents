# Command: /respond-comments

**Propósito**: Genera y opcionalmente publica respuestas a comentarios en Instagram y Facebook.
**Modelo**: `claude-sonnet-4-6`
**Skills usados**: `respond-comments.md`

---

## Cuándo usar este command

Usar después de recibir el reporte de `/social-report`, o en cualquier momento para
responder comentarios pendientes en Instagram y/o Facebook.

También puede ejecutarse autónomamente desde el agente de monitoreo cuando detecta
comentarios que requieren respuesta urgente.

## Flujo de ejecución

### Paso 0 — Cargar variables de entorno

```bash
# Local: carga .env si existe | Railway: no-op (vars ya en entorno)
[ -f .env ] && export $(grep -v '^#' .env | xargs)
```

---

### Paso 1 — Obtener comentarios pendientes

Si no se pasan comentarios explícitamente, leer del reporte más reciente:

```
Archivo: .claude/reports/{FECHA_MÁS_RECIENTE}.json
Filtrar: comentarios con status = "pending_response"
```

Si no hay reporte, consultar directamente la API:

**Instagram — Comentarios recientes:**
```
GET https://graph.facebook.com/v18.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/media
  ?fields=id,caption,timestamp,comments{id,text,username,timestamp,replies{id,text,username}}
  &limit=10
  &access_token={INSTAGRAM_ACCESS_TOKEN}
```

**Facebook — Comentarios recientes:**
```
GET https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/feed
  ?fields=id,message,created_time,comments{id,message,from,created_time}
  &limit=10
  &access_token={FACEBOOK_ACCESS_TOKEN}
```

### Paso 2 — Recopilar contexto de empresa

Leer de CLAUDE.md o variables de entorno:
- `COMPANY_NAME` — nombre de la empresa
- `INDUSTRY` — sector industrial
- `BRAND_VOICE` — descripción del tono de marca (si está configurado)
- `DEFAULT_TONE` — tono por defecto si no hay brand_voice

Si `BRAND_VOICE` no está definido, usar:
```
Tono profesional, cercano y experto en {INDUSTRY}. Respuestas concisas y útiles.
```

### Paso 3 — Clasificar y generar respuestas

Invocar el skill `respond-comments.md` con:
- `comments` — lista de comentarios obtenidos
- `company_name` — de CLAUDE.md
- `industry` — de CLAUDE.md
- `brand_voice` — de CLAUDE.md o default
- `platform` — detectar según origen del comentario
- `post_context` — caption/message del post que recibió el comentario

El skill retorna para cada comentario:
- `comment_type` y `priority`
- `public_response` — texto para publicar
- `private_followup` — DM sugerido si aplica
- `action` — responder | ocultar | reportar | escalar_a_humano
- `escalation_reason` — si requiere revisión humana

### Paso 4 — Mostrar preview y confirmar

Mostrar al usuario las respuestas generadas, ordenadas por prioridad:

```
## RESPUESTAS GENERADAS
Plataforma: {PLATFORM} | Comentarios: {N}
Generado: {FECHA} {HORA}

═══════════════════════════════════════

🚨 URGENTES ({N_URGENTE})
---
@{username} → {comment_type}
Comentario: "{original_comment}"
Respuesta: "{public_response}"
{si private_followup}: DM sugerido: "{private_followup}"
Acción: {action}
---

✅ ALTA PRIORIDAD ({N_ALTA})
[...]

📋 MEDIA/BAJA PRIORIDAD ({N_MEDIA_BAJA})
[...]

⚠️ ESCALAR A HUMANO ({N_ESCALAR})
[Listado con razón de escalación]

═══════════════════════════════════════

¿Qué deseas hacer?
A) Publicar TODAS las respuestas (excepto las de escalación)
B) Publicar solo URGENTES y ALTAS
C) Revisar y aprobar una por una
D) Solo guardar, no publicar todavía
```

Esperar selección del usuario.

### Paso 5 — Publicar respuestas aprobadas

Según la selección del usuario, publicar las respuestas aprobadas.

**Instagram — Responder comentario:**
```
POST https://graph.facebook.com/v18.0/{COMMENT_ID}/replies
  ?message={PUBLIC_RESPONSE_URL_ENCODED}
  &access_token={INSTAGRAM_ACCESS_TOKEN}
```

**Facebook — Responder comentario:**
```
POST https://graph.facebook.com/v18.0/{COMMENT_ID}/comments
  ?message={PUBLIC_RESPONSE_URL_ENCODED}
  &access_token={FACEBOOK_ACCESS_TOKEN}
```

**Ocultar comentario (spam/ofensivo):**
```
POST https://graph.facebook.com/v18.0/{COMMENT_ID}
  ?is_hidden=true
  &access_token={ACCESS_TOKEN}
```

Para cada respuesta publicada:
- Verificar respuesta HTTP 200 ✅
- En error: mostrar error y continuar con los siguientes
- Registrar `comment_id`, `response_text`, `published_at`, `status`

### Paso 6 — Confirmar y guardar

Mostrar resumen final y guardar en `.claude/responses/{FECHA}.json`:

```json
{
  "date": "2026-02-27",
  "platform": "instagram",
  "total_comments": 8,
  "responded": 6,
  "escalated": 1,
  "hidden": 1,
  "avg_response_time_min": 12,
  "responses": [
    {
      "comment_id": "...",
      "username": "@...",
      "type": "consulta_comercial",
      "priority": "urgente",
      "public_response": "...",
      "private_followup": "...",
      "action_taken": "respondido",
      "published_at": "2026-02-27T14:32:00Z"
    }
  ]
}
```

Mensaje final:
```
✅ Respuestas publicadas: {N}
⚠️  Escaladas a humano: {N}
🚫 Ocultadas: {N}

💾 Guardado en: .claude/responses/2026-02-27.json

📌 PENDIENTES PARA HUMANO:
{Lista de comentarios escalados con razón}
```

## Opciones del command

```bash
/respond-comments                    # Responde todos los pendientes
/respond-comments urgent             # Solo responde urgentes
/respond-comments instagram          # Solo Instagram
/respond-comments facebook           # Solo Facebook
/respond-comments preview            # Solo muestra preview, no publica
/respond-comments --post {POST_ID}   # Solo comentarios de un post específico
```

## Variables de entorno requeridas

```env
INSTAGRAM_ACCESS_TOKEN=...
INSTAGRAM_BUSINESS_ACCOUNT_ID=...
FACEBOOK_ACCESS_TOKEN=...
FACEBOOK_PAGE_ID=...
COMPANY_NAME=...
INDUSTRY=...
BRAND_VOICE=...          # Opcional — descripción del tono de marca
```

## Manejo de errores

| Error | Causa probable | Acción |
|---|---|---|
| 400 Invalid parameter | Token expirado o comentario eliminado | Renovar token, continuar con siguientes |
| 403 Permissions | Falta permiso `instagram_manage_comments` | Notificar y pedir reconfiguración |
| 429 Rate limit | Muchas respuestas seguidas | Esperar 60s y reintentar |
| Comentario no encontrado | Ya fue borrado por el usuario | Marcar como "comentario eliminado" y continuar |
