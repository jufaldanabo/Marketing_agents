# Command: /setup-check

**Propósito**: Verifica que todas las credenciales y conexiones estén funcionando
antes del primer deploy o después de cambiar credenciales.
**Modelo**: No requiere Claude para la mayoría de checks — llama a las APIs directamente.
**Skills usados**: `check-token-expiry.md`

---

## Cuándo ejecutar

| Momento | Por qué |
|---|---|
| Antes del primer deploy a Railway | Confirmar que todo funciona |
| Después de rotar o renovar credenciales | Verificar que el nuevo token es válido |
| Cuando un agente falla sin razón aparente | Diagnóstico rápido |
| Después de instalar el toolkit en un nuevo cliente | Onboarding validado |

---

## Flujo de ejecución

### Paso 1 — Verificar variables de entorno

Verificar que las siguientes variables de entorno están configuradas:

**Esenciales (sin estas nada funciona):**
- `ANTHROPIC_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `COMPANY_NAME`
- `INDUSTRY`

**Para publicación (Instagram + Facebook):**
- `INSTAGRAM_ACCESS_TOKEN`
- `INSTAGRAM_BUSINESS_ACCOUNT_ID`
- `FACEBOOK_ACCESS_TOKEN`
- `FACEBOOK_PAGE_ID`
- `FACEBOOK_APP_ID`
- `FACEBOOK_APP_SECRET`

**Para TikTok (si está configurado):**
- `TIKTOK_ACCESS_TOKEN`
- `TIKTOK_OPEN_ID`

**Para prospección:**
- `PRODUCT`
- `INDUSTRY_TARGET`
- `GEOGRAPHY`
- `SENDER_NAME`
- `SENDER_ROLE`

Si una variable esencial no existe → marcar 🔴 y continuar con el resto de checks.
Si una variable opcional no existe → marcar ⚪ (no configurado — opcional).

### Paso 2 — Verificar Anthropic API

```
POST https://api.anthropic.com/v1/messages
Headers:
  x-api-key: {ANTHROPIC_API_KEY}
  anthropic-version: 2023-06-01
  content-type: application/json
Body:
  {
    "model": "claude-haiku-4-5",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "di: ok"}]
  }
```

- ✅ Responde con status 200 → API key válida
- 🔴 Status 401 → API key inválida o expirada
- 🔴 Status 403 → API key sin permisos (verificar en console.anthropic.com)
- 🟡 Status 529 → sobrecarga temporal (no es error de configuración)

### Paso 3 — Verificar Instagram

**3a. Verificar token básico:**
```
GET https://graph.instagram.com/me
  ?fields=id,username,account_type
  &access_token={INSTAGRAM_ACCESS_TOKEN}
```
- ✅ Devuelve `id` y `username` → token válido
- 🔴 Error → token inválido o expirado

**3b. Verificar Business Account ID:**
```
GET https://graph.facebook.com/{INSTAGRAM_BUSINESS_ACCOUNT_ID}
  ?fields=id,name,username,followers_count
  &access_token={INSTAGRAM_ACCESS_TOKEN}
```
- ✅ Devuelve datos de la cuenta → ID correcto
- 🔴 Error OAuthException → token no tiene acceso a esta cuenta

**3c. Verificar vencimiento del token:**
Ejecutar skill `check-token-expiry.md` para Instagram.

**3d. Verificar permisos de Instagram:**
```
GET https://graph.facebook.com/me/permissions
  ?access_token={INSTAGRAM_ACCESS_TOKEN}
```
Verificar que estén presentes: `instagram_basic`, `instagram_content_publish`,
`instagram_manage_comments`, `instagram_manage_insights`.

### Paso 4 — Verificar Facebook

**4a. Verificar página:**
```
GET https://graph.facebook.com/{FACEBOOK_PAGE_ID}
  ?fields=id,name,fan_count,link
  &access_token={FACEBOOK_ACCESS_TOKEN}
```
- ✅ Devuelve datos de la página → todo correcto
- 🔴 Error → page ID incorrecto o token sin acceso

**4b. Verificar permisos de publicación:**
```
GET https://graph.facebook.com/{FACEBOOK_PAGE_ID}?fields=tasks&access_token={FACEBOOK_ACCESS_TOKEN}
```
Verificar que `tasks` incluye `CREATE_CONTENT` o `MANAGE`.

**4c. Verificar vencimiento:**
Ejecutar skill `check-token-expiry.md` para Facebook.

### Paso 5 — Verificar Telegram

**5a. Verificar que el bot existe:**
```
GET https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getMe
```
- ✅ Devuelve datos del bot (username, id) → token válido
- 🔴 Error → bot token inválido

**5b. Enviar mensaje de prueba al chat configurado:**
```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "🔍 /setup-check ejecutado — Conexión con Telegram ✅\nFecha: {FECHA_HOY}\nEmpresa: {COMPANY_NAME}"
}
```
- ✅ Si el mensaje llega → chat_id correcto y bot tiene acceso al chat
- 🔴 Si error 400 → chat_id incorrecto o bot no está en el chat

Si el mensaje de prueba no llega, incluir instrucciones:
```
Para que el bot pueda enviarte mensajes:
1. Abre Telegram y busca tu bot (@nombre_bot)
2. Presiona "Start" o envía /start
3. Para grupos: agrega el bot al grupo y asegúrate de que sea admin
4. Tu TELEGRAM_CHAT_ID es tu ID personal o el ID del grupo
   Para obtenerlo: https://api.telegram.org/bot{TOKEN}/getUpdates
   (envía un mensaje al bot o al grupo primero)
```

### Paso 6 — Verificar TikTok (si está configurado)

Si `TIKTOK_ACCESS_TOKEN` existe:

```
GET https://open.tiktokapis.com/v2/user/info/
  ?fields=open_id,union_id,display_name,avatar_url
Headers:
  Authorization: Bearer {TIKTOK_ACCESS_TOKEN}
```
- ✅ Devuelve datos del usuario → token válido
- 🔴 Error → token inválido o expirado

### Paso 7 — Generar reporte final

```
## 🔍 SETUP CHECK — {COMPANY_NAME}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fecha: {FECHA_HOY}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VARIABLES DE ENTORNO
✅ ANTHROPIC_API_KEY       configurada
✅ TELEGRAM_BOT_TOKEN      configurada
✅ COMPANY_NAME            Textiles Andina
⚪ TIKTOK_ACCESS_TOKEN     no configurada (opcional)
...

SERVICIOS
✅ Anthropic API           Conectado (claude-haiku-4-5 respondió)
✅ Instagram               @textiles_andina | Business Account
✅ Facebook                Textiles Andina | 3,420 seguidores
✅ Telegram                @textiles_bot está activo — mensaje de prueba enviado ✓
⚪ TikTok                  No configurado

TOKENS META
✅ Instagram token         Válido — vence en 47 días (15 abr 2026)
✅ Facebook token          Válido — sin vencimiento (token de página)

PERMISOS META
✅ instagram_content_publish  ✓
✅ pages_manage_posts          ✓
⚠️ instagram_manage_insights  ✗ (necesario para /social-report)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VEREDICTO: 🟡 CASI LISTO

✅ 4 checks pasados
🟡 1 permiso faltante
⚪ 1 servicio no configurado (TikTok — opcional)

ACCIÓN REQUERIDA:
→ Agregar permiso instagram_manage_insights:
  1. Ir a developers.facebook.com → Explorador de la API Graph
  2. Agregar scope: instagram_manage_insights
  3. Regenerar token y actualizar INSTAGRAM_ACCESS_TOKEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Veredictos posibles:**
- ✅ `LISTO PARA PRODUCCIÓN` — todos los checks esenciales pasados
- 🟡 `CASI LISTO` — hay permisos faltantes o servicios opcionales sin configurar
- 🔴 `NO LISTO` — hay credenciales inválidas o servicios esenciales sin conexión

### Paso 8 — Si todo está OK, ofrecer siguiente paso

```
¿Quieres ejecutar ahora?
→ /publish-today       — Publicar primer post de prueba
→ /setup-railway       — Configurar despliegue automático
→ /security-audit      — Auditoría de seguridad antes del deploy
```

---

## Opciones del command

```bash
/setup-check                    # Check completo
/setup-check --quick            # Solo variables + conexión básica (sin tests de permisos)
/setup-check --instagram        # Solo verificar Instagram
/setup-check --facebook         # Solo verificar Facebook
/setup-check --tiktok           # Solo verificar TikTok
/setup-check --telegram         # Solo verificar Telegram + enviar mensaje de prueba
/setup-check --tokens           # Solo verificar vencimiento de tokens Meta
```

---

## Notas de implementación

- Ejecutar los checks de forma secuencial (no paralela) para mejor diagnóstico
- Capturar el HTTP status code de cada llamada, no solo si hubo error de red
- Si un check falla, continuar con los siguientes (no abortar)
- Guardar el resultado del check en `.claude/runs/setup-check-{FECHA}.json` para histórico
