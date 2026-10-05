---
name: preflight-check
description: Valida credenciales, conectividad y precondiciones antes de ejecutar operaciones externas. Falla rápido con mensaje claro si algo no está listo.
allowed-tools: [Bash, Read]
model: claude-haiku-4-5
---

# Skill: preflight-check

**Propósito**: Antes de que un agente intente publicar, enviar outreach o consumir una API, verificar que todo esté configurado. Reduce debugging downstream mostrando el error en el punto correcto.

**Principio**: Fail fast, fail clear.

---

## Cuándo invocar

Al inicio de todo agente o command que vaya a hacer **operaciones externas**:
- Publicación en IG/FB/TikTok
- Envío de mensajes Telegram
- Prospección (webfetch de perfiles públicos)
- Monitoreo de precios (webfetch de fuentes)

## Cuándo NO invocar

- Operaciones puramente locales (`/briefing`, `/brand-kit`, lectura de archivos)
- Dentro de skills que ya reciben contexto validado del agente padre

---

## Checks disponibles

El invocador especifica qué dominios chequear:

```
preflight-check --domains anthropic,meta,telegram
```

### `anthropic`
- Variable `ANTHROPIC_API_KEY` existe y empieza con `sk-ant-`
- (Opcional) Test call liviano a `/v1/models` para validar que el key funciona

### `meta` (Instagram + Facebook)
- `INSTAGRAM_ACCESS_TOKEN` definido
- `INSTAGRAM_BUSINESS_ACCOUNT_ID` definido
- `FACEBOOK_ACCESS_TOKEN` definido
- `FACEBOOK_PAGE_ID` definido
- Test call: `GET https://graph.facebook.com/v18.0/me?access_token=${TOKEN}` → debe devolver `{id, name}`
- Verificar expiración: `GET https://graph.facebook.com/debug_token?input_token=${TOKEN}&access_token=${APP_ID}|${APP_SECRET}`
  - Si expira en <3 días → error crítico
  - Si expira en <10 días → warning (no bloqueante)

### `tiktok`
- `TIKTOK_ACCESS_TOKEN` definido
- `TIKTOK_OPEN_ID` definido
- Test call: `GET https://open.tiktokapis.com/v2/user/info/?fields=open_id` con header `Authorization: Bearer ${TOKEN}`
- TikTok tokens expiran a las 24h — verificar siempre antes de publicar

### `telegram`
- `TELEGRAM_BOT_TOKEN` definido
- `TELEGRAM_CHAT_ID` definido
- Test call: `GET https://api.telegram.org/bot${TOKEN}/getMe` → debe devolver `{ok: true, result: {...}}`
- Opcional: `GET https://api.telegram.org/bot${TOKEN}/getChat?chat_id=${CHAT_ID}` para verificar que el bot es miembro del chat

### `fal` (opcional, solo si se van a generar imágenes)
- `FAL_KEY` definido
- No se hace test call para no gastar créditos; se verifica solo presencia

### `brief`
- `.claude/client-brief.json` existe y es válido (invoca `load-brief`)

### `brand-kit`
- `.claude/brand-kit.json` existe (si no → warning, hay fallback)

### `state-dir`
- `.claude/state/` existe (si no, crearlo)

---

## Flujo

### Paso 1 — Parsear dominios solicitados

Del input `--domains anthropic,meta,telegram`, obtener array.

### Paso 2 — Ejecutar cada check en secuencia

Para cada dominio:
1. Verificar variables de entorno con `[ -n "$VAR" ]`
2. Si procede, ejecutar test call con `curl` y timeout de 10s
3. Clasificar resultado: `ok`, `warning`, `critical`

### Paso 3 — Compilar reporte

```json
{
  "ok": true,
  "domains_checked": ["anthropic", "meta", "telegram"],
  "results": {
    "anthropic": {"status": "ok", "detail": "API key válido"},
    "meta": {
      "status": "warning",
      "detail": "Token expira en 7 días",
      "actions": ["Renovar token con /setup-check --rotate-tokens"]
    },
    "telegram": {"status": "ok", "detail": "Bot responde, chat accesible"}
  },
  "has_critical": false,
  "has_warnings": true
}
```

Si `has_critical = true`, el invocador DEBE abortar su operación.

### Paso 4 — Loggar

Invocar `state-store append-log` con el reporte compacto.

---

## Mensajes de error estándar

### Variable faltante
```
❌ CREDENCIAL FALTANTE: {VAR_NAME}

Esta variable es requerida para operar en {DOMAIN}.

Agrégala a tu .env del proyecto:
  {VAR_NAME}=...

Guía: /setup-check --help {domain}
```

### Credencial inválida
```
❌ CREDENCIAL INVÁLIDA: {VAR_NAME}

La API de {PLATFORM} devolvió: {ERROR_MESSAGE}

Posibles causas:
- Token revocado
- Token expirado
- Token sin permisos suficientes

Solución: Regenerar en {PLATFORM_URL} y actualizar .env
```

### Token por expirar
```
⚠️ TOKEN POR EXPIRAR: {PLATFORM}

Tu token de {PLATFORM} expira en {N} días.

Recomendado: Renovar YA con /setup-check --rotate-tokens
```

---

## Formato de salida al invocador

**Éxito total**:
```json
{"ok": true, "has_critical": false, "has_warnings": false}
```

**Con warnings**:
```json
{
  "ok": true,
  "has_critical": false,
  "has_warnings": true,
  "warnings": ["Token Meta expira en 7 días"]
}
```

**Con fallas críticas** (invocador debe abortar):
```json
{
  "ok": false,
  "has_critical": true,
  "critical_errors": [
    {"domain": "meta", "error": "INSTAGRAM_ACCESS_TOKEN no definido"}
  ],
  "message": "No se puede continuar. Resolver errores críticos antes de reintentar."
}
```

---

## Notas

- Este skill NO modifica credenciales ni intenta renovar tokens automáticamente.
- No falla por warnings — solo por críticos.
- Los test calls tienen timeout de 10s para no bloquear la ejecución del invocador.
- Idempotente: se puede llamar múltiples veces sin side effects (más allá del log).
