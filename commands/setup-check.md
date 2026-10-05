# Command: /setup-check

**Propósito**: Verifica que todas las credenciales, archivos de contexto y conexiones estén funcionando antes del primer deploy, al rotar tokens o antes de ejecutar un command específico.
**Modelo**: No requiere Claude para la mayoría de checks — llama a las APIs directamente.
**Skills usados**: `_core/preflight-check`, `_core/load-brief`, `check-token-expiry.md`

---

## Cuándo ejecutar

| Momento | Por qué |
|---|---|
| Antes del primer deploy a Railway | Confirmar que todo funciona |
| Después de rotar o renovar credenciales | Verificar que el nuevo token es válido |
| Cuando un agente falla sin razón aparente | Diagnóstico rápido |
| Antes de ejecutar un command por primera vez | `--pre-{command}` valida solo lo necesario |
| Después de instalar el toolkit en un nuevo cliente | Onboarding validado |

---

## Flujo de ejecución

### Paso 0 — Resolver scope del check

Según el flag recibido, decidir qué dominios chequear:

| Flag | Dominios validados |
|---|---|
| (sin flag) | `anthropic, meta, tiktok, telegram, meta_ads, tiktok_ads, fal` (completo) |
| `--quick` | `anthropic, telegram` (mínimo viable) |
| `--rotate-tokens` | `meta, tiktok` + mostrar flujo guiado de renovación |
| `--pre-publish-today` | `anthropic, meta, telegram, fal` |
| `--pre-content-calendar` | `anthropic, telegram` |
| `--pre-paid-media` | `anthropic, meta_ads, tiktok_ads, telegram` |
| `--pre-social-report` | `anthropic, meta, telegram` |
| `--pre-prospect-leads` | `anthropic, telegram` + variables de prospección |
| `--instagram` / `--facebook` / `--tiktok` / `--telegram` / `--tokens` | Un solo dominio |

### Paso 1 — Verificar contexto del cliente (brief + brand-kit)

**1a. Brief v2.0:**
```
Leer .claude/client-brief.json
```
- ✅ Existe y valida contra schema v2.0 → mostrar `brief.company.name`, `brief.industry`, `brief.budget.paid_media_monthly`, `brief.channels[]`
- 🔴 No existe → sugerir `/init`
- 🟡 Existe pero `schema_version != "2.0"` → sugerir migración

**1b. Brand kit:**
```
Leer .claude/brand-kit.json
```
- ✅ Existe → mostrar `tone`, `palette`, `fonts`, `visual_style`
- 🟡 No existe → sugerir ejecutar skill `define-brand-kit` o command `/content-calendar` (lo genera si falta)

**1c. Estado del sistema:**
```
Verificar que exista .claude/state/ con subdirectorios:
  .claude/state/
  ├── drafts/
  ├── calendar/
  ├── leads/
  ├── runs/
  └── audits/
```
- ✅ Existen → OK
- 🟡 Faltan algunos → crearlos vacíos

### Paso 2 — Delegar validación a `_core/preflight-check`

Invocar `_core/preflight-check --domains {LISTA_DE_PASO_0}`.

El preflight se encarga de la lógica real por dominio; aquí sólo se interpreta su reporte. Dominios soportados:

**anthropic** — `POST /v1/messages` con haiku-4-5
- ✅ 200 → OK
- 🔴 401/403 → key inválida o sin permisos
- 🟡 529 → sobrecarga (no es error de config)

**meta** (Instagram + Facebook + token expiry):
- `GET graph.instagram.com/me?fields=id,username,account_type`
- `GET graph.facebook.com/{IG_BUSINESS_ID}?fields=id,name,followers_count`
- `GET graph.facebook.com/{FB_PAGE_ID}?fields=id,name,fan_count,tasks`
- `GET /me/permissions` → debe incluir `instagram_basic`, `instagram_content_publish`, `instagram_manage_comments`, `instagram_manage_insights`, `pages_manage_posts`, `pages_read_engagement`
- Delegar a `check-token-expiry.md` para IG y FB. Umbrales: <3d 🔴, <10d 🟠, <30d 🟡.

**tiktok** — `GET open.tiktokapis.com/v2/user/info/`
- Token de 24h → siempre advertir si quedan <2h

**telegram** — `GET /getMe` + `POST /sendMessage` de prueba

**meta_ads** — `GET /{AD_ACCOUNT_ID}?fields=id,name,account_status,currency,amount_spent`
- Requiere `META_AD_ACCOUNT_ID` + token con `ads_management` + `ads_read`
- 🔴 **Crítico si** `brief.budget.paid_media_monthly > 0` pero falta credencial o permiso

**tiktok_ads** — `GET /advertiser/info/` del TikTok Business API
- 🔴 **Crítico si** `brief.budget.paid_media_monthly > 0` y hay channel `tiktok_ads` en brief

**fal** — `GET fal.ai/me` con `FAL_KEY`
- 🟡 Si no existe pero el brief implica generación de imagen → warning

### Paso 3 — Flujo guiado de rotación (`--rotate-tokens`)

Si se pasa este flag, además del check, mostrar:

```
🔁 ROTACIÓN DE TOKENS META
━━━━━━━━━━━━━━━━━━━━━━━━
Token actual IG: vence en {DIAS}d ({FECHA})
Token actual FB: {sin vencimiento | vence en {DIAS}d}

PASOS:
1. Abre: developers.facebook.com/tools/explorer/
2. Selecciona app: {FACEBOOK_APP_ID}
3. Scopes requeridos:
   instagram_basic, instagram_content_publish,
   instagram_manage_comments, instagram_manage_insights,
   pages_manage_posts, pages_read_engagement,
   ads_management, ads_read {si paid_media_monthly > 0}
4. Genera user token → Debug → "Extend Access Token" (60 días)
5. Pega el nuevo token aquí: ______

[Opcional] Si quieres, puedo escribirlo en .env automáticamente (S/N).
```

Al confirmar, actualizar `.env` y re-ejecutar la validación de Meta.

### Paso 4 — Generar reporte final

```
## 🔍 SETUP CHECK — {COMPANY_NAME}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fecha: {FECHA_HOY}  |  Scope: {FLAG}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXTO DEL CLIENTE
✅ .claude/client-brief.json         v2.0 — {EMPRESA} / {INDUSTRIA}
✅ .claude/brand-kit.json            tono {TONO}, {N_CANALES} canales
✅ .claude/state/                    5/5 subdirectorios

VARIABLES DE ENTORNO
✅ ANTHROPIC_API_KEY       configurada
✅ TELEGRAM_BOT_TOKEN      configurada
⚪ TIKTOK_ACCESS_TOKEN     no configurada (opcional)
...

SERVICIOS
✅ Anthropic API           claude-haiku-4-5 respondió
✅ Instagram               @{USERNAME} — {FOLLOWERS} seguidores
✅ Facebook                {PAGE_NAME} — {FANS} seguidores
✅ Telegram                mensaje de prueba enviado ✓
⚪ TikTok                  no configurado
🔴 Meta Ads                NO configurado — brief.budget.paid_media_monthly={USD}/mes
🟡 fal.ai                  key presente pero cuota 90% consumida

TOKENS META
🟠 Instagram token         vence en 8 días (14 oct 2026)  → ejecuta /setup-check --rotate-tokens
✅ Facebook token          sin vencimiento (page token)

PERMISOS META
✅ instagram_content_publish
✅ pages_manage_posts
⚠️ ads_management           FALTA (requerido por paid_media)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VEREDICTO: 🔴 NO LISTO (paid media sin credenciales)

ACCIÓN REQUERIDA:
→ Configurar META_AD_ACCOUNT_ID + scope ads_management
→ Renovar token de Instagram antes del 14 oct
→ /setup-check --rotate-tokens
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Veredictos posibles:**
- ✅ `LISTO PARA PRODUCCIÓN` — todos los dominios críticos pasan
- 🟡 `CASI LISTO` — permisos opcionales o canales no activados en brief faltan
- 🔴 `NO LISTO` — credenciales inválidas, o `paid_media_monthly > 0` sin credenciales de ads, o brief faltante

### Paso 5 — Siguiente paso sugerido

```
Siguiente paso:
→ /publish-today       — primer post de prueba
→ /content-calendar    — generar parrilla mensual
→ /setup-railway       — desplegar en Railway (13 agentes)
→ /security-audit      — auditoría previa al deploy
```

### Paso 6 — Guardar histórico

Guardar reporte en `.claude/state/audits/setup-check-{FECHA}.json` con:
- scope ejecutado
- resultado por dominio
- veredicto
- acciones recomendadas

---

## Opciones del command

```bash
/setup-check                           # Check completo (todos los dominios)
/setup-check --quick                   # Solo anthropic + telegram
/setup-check --rotate-tokens           # Check Meta + flujo guiado de renovación
/setup-check --instagram               # Solo Instagram
/setup-check --facebook                # Solo Facebook
/setup-check --tiktok                  # Solo TikTok
/setup-check --telegram                # Solo Telegram + mensaje de prueba
/setup-check --tokens                  # Solo vencimiento de tokens Meta
/setup-check --pre-publish-today       # Precondiciones de /publish-today
/setup-check --pre-content-calendar    # Precondiciones de /content-calendar
/setup-check --pre-paid-media          # Precondiciones de paid media
/setup-check --pre-social-report       # Precondiciones de /social-report
/setup-check --pre-prospect-leads      # Precondiciones de /prospect-leads
```

---

## Notas de implementación

- Secuencial, no paralelo — mejor diagnóstico.
- Capturar HTTP status, no solo errores de red.
- Si un check falla, continuar con los siguientes (no abortar).
- Si falta brief → sugerir `/init`, no asumir defaults.
- Si `brief.budget.paid_media_monthly > 0` y faltan credenciales de ads → **veredicto 🔴 crítico**, no 🟡.
- Guardar resultado en `.claude/state/audits/setup-check-{FECHA}.json`.
