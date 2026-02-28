# Skill: check-token-expiry

**Propósito**: Verifica la fecha de vencimiento de los tokens de Meta API (Instagram y Facebook)
y envía alerta por Telegram si quedan menos de 10 días para el vencimiento.
**Modelo**: No requiere Claude — llama directamente a la Meta Graph API
**Usado por**: `social-report.md`, `/setup-check`

---

## Cuándo usar este skill

- Cada noche durante el `/social-report` (verificación preventiva)
- Al ejecutar `/setup-check` (diagnóstico inicial)
- Después de renovar un token (para confirmar que el nuevo es válido)

## Inputs requeridos

| Input | Fuente | Descripción |
|---|---|---|
| `INSTAGRAM_ACCESS_TOKEN` | `.env` | Token de acceso de Instagram |
| `FACEBOOK_ACCESS_TOKEN` | `.env` | Token de acceso de Facebook |
| `FACEBOOK_APP_ID` | `.env` | App ID de la aplicación en Meta Developers |
| `FACEBOOK_APP_SECRET` | `.env` | App Secret de la aplicación |
| `TELEGRAM_BOT_TOKEN` | `.env` | Para enviar alertas |
| `TELEGRAM_CHAT_ID` | `.env` | Destinatario de las alertas |

## Paso 1 — Verificar token de Instagram

```
GET https://graph.facebook.com/debug_token
  ?input_token={INSTAGRAM_ACCESS_TOKEN}
  &access_token={FACEBOOK_APP_ID}|{FACEBOOK_APP_SECRET}
```

**Respuesta esperada:**
```json
{
  "data": {
    "app_id": "123456",
    "type": "USER",
    "application": "Mi App",
    "expires_at": 1753920000,
    "is_valid": true,
    "scopes": ["instagram_basic", "instagram_content_publish", "pages_show_list"]
  }
}
```

**Calcular días restantes:**
```
dias_restantes = (expires_at - unix_timestamp_ahora) / 86400
```

Si `is_valid` es `false` → el token ya expiró → alerta CRÍTICA inmediata.

## Paso 2 — Verificar token de Facebook

Mismo endpoint con `input_token={FACEBOOK_ACCESS_TOKEN}`:

```
GET https://graph.facebook.com/debug_token
  ?input_token={FACEBOOK_ACCESS_TOKEN}
  &access_token={FACEBOOK_APP_ID}|{FACEBOOK_APP_SECRET}
```

Los tokens de página de Facebook tienen larga duración (no expiran), pero hay que verificar
que sigan siendo válidos y que los permisos estén activos.

## Paso 3 — Evaluar resultado y actuar

| Situación | Acción |
|---|---|
| `is_valid: false` | 🔴 Alerta CRÍTICA por Telegram — publicación detenida |
| `dias_restantes < 3` | 🔴 Alerta URGENTE — renovar HOY |
| `dias_restantes < 10` | 🟠 Alerta preventiva — renovar esta semana |
| `dias_restantes 10-30` | 🟡 Aviso en el reporte nocturno (sin Telegram aparte) |
| `dias_restantes > 30` | ✅ Sin acción — solo registrar en el reporte |

## Paso 4 — Enviar alerta por Telegram (si aplica)

### Alerta CRÍTICA (token inválido o < 3 días)

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "🔴 ALERTA CRÍTICA — TOKEN META EXPIRADO\n\n❌ {PLATAFORMA}: Token inválido o expirado\n\n⚠️ Las publicaciones automáticas están DETENIDAS.\n\nPasos para renovar:\n1. Ir a developers.facebook.com\n2. Herramientas → Explorador de la API Graph\n3. Generar token con permisos: instagram_content_publish, pages_manage_posts\n4. Actualizar INSTAGRAM_ACCESS_TOKEN en las variables de Railway\n5. Ejecutar /setup-check para confirmar\n\nFecha: {FECHA_HOY}",
  "parse_mode": "Markdown"
}
```

### Alerta preventiva (< 10 días)

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "⚠️ AVISO — Token de {PLATAFORMA} vence pronto\n\n📅 Vence el: {FECHA_VENCIMIENTO}\n⏳ Días restantes: {DIAS_RESTANTES}\n\nRenovar antes del {FECHA_LIMITE} para evitar interrupciones.\n\nVer guía: developers.facebook.com → Explorador de la API Graph",
  "parse_mode": "Markdown"
}
```

## Paso 5 — Verificar permisos requeridos

Además del vencimiento, verificar que el token tenga los permisos mínimos necesarios:

**Permisos requeridos para Instagram:**
- `instagram_basic`
- `instagram_content_publish`
- `instagram_manage_comments`
- `instagram_manage_insights`

**Permisos requeridos para Facebook:**
- `pages_show_list`
- `pages_manage_posts`
- `pages_read_engagement`
- `pages_manage_engagement`

Si faltan permisos → incluir en el reporte con instrucciones para agregar el scope faltante.

## Output del skill

```json
{
  "instagram": {
    "is_valid": true,
    "expires_at": "2026-04-15",
    "days_remaining": 47,
    "status": "ok",
    "missing_permissions": [],
    "alert_sent": false
  },
  "facebook": {
    "is_valid": true,
    "expires_at": "never",
    "days_remaining": null,
    "status": "ok",
    "missing_permissions": [],
    "alert_sent": false
  },
  "summary": "✅ Tokens válidos. Instagram vence en 47 días.",
  "checked_at": "2026-02-27T23:00:00"
}
```

## Cómo renovar un token de Instagram (guía rápida)

Incluir en el reporte cuando `dias_restantes < 30`:

```
RENOVAR TOKEN DE INSTAGRAM:
1. Ir a https://developers.facebook.com/tools/explorer/
2. Seleccionar tu App en el dropdown
3. Agregar permisos: instagram_basic, instagram_content_publish,
   instagram_manage_comments, pages_show_list, pages_manage_posts
4. Clic en "Generar token de acceso"
5. Copiar el token corto → ir a:
   GET https://graph.facebook.com/oauth/access_token
     ?grant_type=fb_exchange_token
     &client_id={APP_ID}
     &client_secret={APP_SECRET}
     &fb_exchange_token={TOKEN_CORTO}
6. Copiar el token largo (válido 60 días)
7. Actualizar INSTAGRAM_ACCESS_TOKEN en Railway y en .env local
8. Ejecutar /setup-check para confirmar
```
