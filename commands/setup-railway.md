# Command: /setup-railway

**Propósito**: Genera todos los archivos necesarios para desplegar el toolkit **v2.0 (13 agentes)** en Railway con cron jobs automáticos.
**Modelo**: `claude-opus-4-6`
**Skills usados**: `schedule-railway.md`

---

## Qué hace este command

1. Crea la carpeta `deploy/` con `scheduler.py`, `railway.toml`, `Dockerfile`, `requirements.txt`, `.env.example`, `README-deploy.md`.
2. Programa los 13 agentes del toolkit (12 cron + 1 on-demand) según el timezone del cliente.
3. Lee `brief.channels[]` y `brief.budget.paid_media_monthly` para decidir qué servicios comentar.
4. Genera instrucciones paso a paso de despliegue.
5. Actualiza `.gitignore` para no subir datos sensibles.

## Flujo de ejecución

### Paso 1 — Recopilar configuración

Preguntar al usuario si no está en `.claude/client-brief.json`:

```
Para configurar el despliegue necesito algunos datos:

1. Timezone (default: UTC-5 Colombia)
   A) UTC-5 (Colombia, Ecuador, Perú)
   B) UTC-6 (México)
   C) UTC-4 (Venezuela, Bolivia)
   D) UTC+1 (España)
   E) UTC+0 (UK, otro)

2. ¿Qué agentes quieres programar? (default: todos los activos según brief)
   □ content-planner          — parrilla mensual
   □ content-publisher        — publica diario
   □ social-monitor           — reporte nocturno
   □ market-analyst           — inteligencia semanal
   □ sales-prospector         — prospección B2B (opcional)
   □ conductor                — orquestador cada hora
   □ approval-gatekeeper      — procesa aprobaciones cada 10 min
   □ account-auditor          — auditoría mensual
   □ community-manager        — ciclos de respuesta cada 4h
   □ performance-analyst      — métricas diario + 72h + semanal + mensual
   □ paid-media               — campañas pagas semanal (si paid_media > 0)
   □ producer                 — rodaje mensual día 20
   ⚡ brand-guardian          — on-demand (no cron)
```

### Paso 2 — Calcular horarios en UTC

Convertir cada horario local a UTC según el timezone elegido.

**Horarios recomendados (ejemplo Colombia UTC-5):**

| Agente | Hora local | Cron UTC | Notas |
|---|---|---|---|
| content-planner | Día 25 09:00 | `0 14 25 * *` | Parrilla del mes siguiente |
| content-publisher | 08:00 L-V | `0 13 * * 1-5` | Diario laboral |
| social-monitor | 22:00 diario | `0 3 * * *` | Reporte nocturno |
| market-analyst | Lunes 07:00 | `0 12 * * 1` | Semanal |
| sales-prospector | Viernes 08:00 | `0 13 * * 5` | Opcional |
| conductor | Cada hora | `0 * * * *` | Procesa eventos del bus |
| approval-gatekeeper | Cada 10 min | `*/10 * * * *` | Lee Telegram |
| account-auditor | Día 1 09:00 | `0 14 1 * *` | Mensual |
| community-manager | Cada 4h | `0 */4 * * *` | Ciclos de respuesta |
| performance-analyst (24h) | 23:00 diario | `0 4 * * *` | 24h-check |
| performance-analyst (72h) | Cada hora | `30 * * * *` | 72h-check sobre posts <72h |
| performance-analyst (semanal) | Lunes 09:00 | `0 14 * * 1` | Reporte semanal |
| performance-analyst (mensual) | Día 1 10:00 | `0 15 1 * *` | Reporte mensual |
| paid-media | Lunes 08:00 | `0 13 * * 1` | Semanal, solo si paid_media > 0 |
| producer | Día 20 09:00 | `0 14 20 * *` | Preparar rodaje del próximo mes |
| brand-guardian | — | on-demand | Sin cron |

Si `brief.budget.paid_media_monthly == 0`, comentar el servicio `paid-media`.

### Paso 3 — Crear estructura de archivos

```
deploy/
├── scheduler.py          ← dispatcher para los 13 agentes
├── requirements.txt      ← claude-agent-sdk, anthropic, httpx
├── railway.toml          ← 15 cron services (performance-analyst tiene 4)
├── Dockerfile            ← Python 3.12 + Node.js + Claude Code CLI
├── .env.example          ← variables requeridas
└── README-deploy.md      ← guía completa
```

**Template de `scheduler.py` (resumen):**

```python
# deploy/scheduler.py
import sys, os, asyncio
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions

AGENTS = {
    "content-planner":       "agents/content-planner.md",
    "content-publisher":     "agents/content-publisher.md",
    "social-monitor":        "agents/social-monitor.md",
    "market-analyst":        "agents/market-analyst.md",
    "sales-prospector":      "agents/sales-prospector.md",
    "conductor":             "agents/conductor.md",
    "approval-gatekeeper":   "agents/approval-gatekeeper.md",
    "account-auditor":       "agents/account-auditor.md",
    "community-manager":     "agents/community-manager.md",
    "performance-analyst":   "agents/performance-analyst.md",
    "paid-media":            "agents/paid-media.md",
    "producer":              "agents/producer.md",
    "brand-guardian":        "agents/brand-guardian.md",   # on-demand only
}

PERF_MODES = {
    "performance-analyst-24h":     "mode=24h",
    "performance-analyst-72h":     "mode=72h",
    "performance-analyst-weekly":  "mode=weekly",
    "performance-analyst-monthly": "mode=monthly",
}

async def run(agent_key: str):
    is_prod = os.getenv("RAILWAY_ENVIRONMENT") == "production"
    opts = ClaudeAgentOptions(
        system_prompt_file=AGENTS[agent_key.split("-")[0]],  # resolver base
        permission_mode="bypassPermissions" if is_prod else "default",
    )
    async with ClaudeSDKClient(options=opts) as client:
        extra = PERF_MODES.get(agent_key, "")
        await client.query(f"Ejecuta tu rutina programada. {extra}")

if __name__ == "__main__":
    asyncio.run(run(sys.argv[1]))
```

**Template de `railway.toml` (fragmento con los 13 agentes):**

```toml
# ─── CONTENIDO ───────────────────────────────────────
[[services]]
name = "content-planner"
startCommand = "python deploy/scheduler.py content-planner"
[services.deploy]
cronSchedule = "0 14 25 * *"   # Día 25 09:00 Colombia

[[services]]
name = "content-publisher"
startCommand = "python deploy/scheduler.py content-publisher"
[services.deploy]
cronSchedule = "0 13 * * 1-5"

[[services]]
name = "producer"
startCommand = "python deploy/scheduler.py producer"
[services.deploy]
cronSchedule = "0 14 20 * *"   # Día 20 — rodaje del próximo mes

# ─── MONITOREO Y COMUNIDAD ───────────────────────────
[[services]]
name = "social-monitor"
startCommand = "python deploy/scheduler.py social-monitor"
[services.deploy]
cronSchedule = "0 3 * * *"

[[services]]
name = "community-manager"
startCommand = "python deploy/scheduler.py community-manager"
[services.deploy]
cronSchedule = "0 */4 * * *"

# ─── PERFORMANCE (4 cadencias) ───────────────────────
[[services]]
name = "performance-analyst-24h"
startCommand = "python deploy/scheduler.py performance-analyst-24h"
[services.deploy]
cronSchedule = "0 4 * * *"

[[services]]
name = "performance-analyst-72h"
startCommand = "python deploy/scheduler.py performance-analyst-72h"
[services.deploy]
cronSchedule = "30 * * * *"

[[services]]
name = "performance-analyst-weekly"
startCommand = "python deploy/scheduler.py performance-analyst-weekly"
[services.deploy]
cronSchedule = "0 14 * * 1"

[[services]]
name = "performance-analyst-monthly"
startCommand = "python deploy/scheduler.py performance-analyst-monthly"
[services.deploy]
cronSchedule = "0 15 1 * *"

# ─── INTELIGENCIA Y COMERCIAL ────────────────────────
[[services]]
name = "market-analyst"
[services.deploy]
cronSchedule = "0 12 * * 1"

# [[services]]              ← Comentar si brief.b2b_sales.enabled = false
# name = "sales-prospector"
# cronSchedule = "0 13 * * 5"

# ─── PAID MEDIA ──────────────────────────────────────
# [[services]]              ← Comentar si paid_media_monthly == 0
# name = "paid-media"
# cronSchedule = "0 13 * * 1"

# ─── AUDITORÍA Y ORQUESTACIÓN ────────────────────────
[[services]]
name = "account-auditor"
[services.deploy]
cronSchedule = "0 14 1 * *"

[[services]]
name = "conductor"
[services.deploy]
cronSchedule = "0 * * * *"

[[services]]
name = "approval-gatekeeper"
[services.deploy]
cronSchedule = "*/10 * * * *"

# brand-guardian: on-demand, sin cron (invocado por otros agentes vía bus)
```

### Paso 4 — Actualizar `.gitignore`

```gitignore
# Datos de empresa y sesiones de Claude Code
.claude/

# Variables de entorno con credenciales
.env
.env.local
.env.*.local

# Logs del scheduler
*.log
deploy/logs/

# Resultados de ejecuciones
.claude/state/
.claude/runs/
.claude/reports/
.claude/posts/
.claude/leads/
.claude/intel/
.claude/drafts/
.claude/audits/
```

### Paso 5 — Mostrar resumen y próximos pasos

```
## ✅ RAILWAY DEPLOYMENT CONFIGURADO (toolkit v2.0 — 13 agentes)
Timezone: UTC-5 (Colombia)

ARCHIVOS GENERADOS:
✅ deploy/scheduler.py       — dispatcher para los 13 agentes
✅ deploy/requirements.txt   — claude-agent-sdk, anthropic, httpx
✅ deploy/railway.toml       — 15 cron services + 1 on-demand
✅ deploy/Dockerfile         — Python 3.12 + Node.js + Claude Code CLI
✅ deploy/.env.example       — variables requeridas (según brief)
✅ deploy/README-deploy.md   — guía completa
✅ .gitignore                — excluye .claude/ y .env

SERVICIOS PROGRAMADOS (hora local):
┌───────────────────────────────┬────────────────────────────┬──────────────────┐
│ Servicio                       │ Horario                    │ Cron (UTC)       │
├───────────────────────────────┼────────────────────────────┼──────────────────┤
│ content-planner                │ Día 25 09:00               │ 0 14 25 * *      │
│ content-publisher              │ L-V 08:00                  │ 0 13 * * 1-5     │
│ producer                       │ Día 20 09:00               │ 0 14 20 * *      │
│ social-monitor                 │ Diario 22:00               │ 0 3 * * *        │
│ community-manager              │ Cada 4h                    │ 0 */4 * * *      │
│ performance-analyst-24h        │ Diario 23:00               │ 0 4 * * *        │
│ performance-analyst-72h        │ Cada hora (:30)            │ 30 * * * *       │
│ performance-analyst-weekly     │ Lunes 09:00                │ 0 14 * * 1       │
│ performance-analyst-monthly    │ Día 1 10:00                │ 0 15 1 * *       │
│ market-analyst                 │ Lunes 07:00                │ 0 12 * * 1       │
│ sales-prospector *             │ Viernes 08:00              │ 0 13 * * 5       │
│ paid-media **                  │ Lunes 08:00                │ 0 13 * * 1       │
│ account-auditor                │ Día 1 09:00                │ 0 14 1 * *       │
│ conductor                      │ Cada hora                  │ 0 * * * *        │
│ approval-gatekeeper            │ Cada 10 min                │ */10 * * * *     │
│ brand-guardian                 │ On-demand                  │ —                │
└───────────────────────────────┴────────────────────────────┴──────────────────┘
* Opcional — activo si brief.b2b_sales.enabled = true
** Activo si brief.budget.paid_media_monthly > 0

══════════════════════════════════════════════════════

PRÓXIMOS PASOS:
1️⃣  Copia deploy/.env.example → .env y completa valores
2️⃣  pip install -r deploy/requirements.txt && python deploy/scheduler.py content-publisher
3️⃣  git add deploy/ .gitignore && git commit -m "Add Railway deployment" && git push
4️⃣  railway login && railway init && railway up
5️⃣  Dashboard → Shared Variables → agregar todas las variables del .env
6️⃣  Trigger manual de cada servicio para verificar notificación Telegram ✅

══════════════════════════════════════════════════════

⚠️  IMPORTANTE:
• Nunca subas .env al repositorio
• Tokens Instagram expiran cada 60d — usa /setup-check --rotate-tokens
• TikTok token dura 24h — refresh via refresh_token (ver schedule-railway.md)
• En Railway usa "Shared Variables" para que todos los servicios compartan credenciales
```

## Opciones del command

```bash
/setup-railway                    # Interactivo (lee brief + pregunta lo faltante)
/setup-railway --timezone utc-5   # Especifica timezone sin preguntar
/setup-railway --dry-run          # Muestra qué archivos crearía sin crearlos
/setup-railway --update-schedules # Solo regenera cron en railway.toml
/setup-railway --agents-only {CSV}  # Solo programa los agentes listados
```

## Variables de entorno requeridas para Railway

**Esenciales:**
- `ANTHROPIC_API_KEY`
- `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID`
- `COMPANY_NAME` + `INDUSTRY`

**Publishing (si hay canales IG/FB en brief):**
- `INSTAGRAM_ACCESS_TOKEN` + `INSTAGRAM_BUSINESS_ACCOUNT_ID`
- `FACEBOOK_ACCESS_TOKEN` + `FACEBOOK_PAGE_ID`
- `FACEBOOK_APP_ID` + `FACEBOOK_APP_SECRET`

**TikTok (si hay canal TikTok en brief):**
- `TIKTOK_ACCESS_TOKEN` + `TIKTOK_OPEN_ID` + `TIKTOK_CLIENT_KEY` + `TIKTOK_CLIENT_SECRET`

**Paid media (si `brief.budget.paid_media_monthly > 0`):**
- `META_AD_ACCOUNT_ID` (y token con scopes `ads_management` + `ads_read`)
- `TIKTOK_ADS_ACCESS_TOKEN` + `TIKTOK_ADVERTISER_ID` (si hay canal `tiktok_ads`)

**Market intelligence:**
- `COMMODITIES` + `COMPETITORS`

**Prospecting (si `brief.b2b_sales.enabled = true`):**
- `PRODUCT` + `INDUSTRY_TARGET` + `GEOGRAPHY`
- `SENDER_NAME` + `SENDER_ROLE`

**Generación de imagen:**
- `FAL_KEY` (opcional pero recomendado)

## Notas técnicas

### Por qué Claude Agent SDK y no API directa

Los agentes usan `WebSearch`, `WebFetch`, `Read`, `Write`, `Bash`. El SDK ejecuta Claude Code con `permission_mode=bypassPermissions` solo cuando `RAILWAY_ENVIRONMENT=production`.

### Costo estimado en Railway

- Hobby ($5/mes base) ya no alcanza con 15 cron services → recomendar **Pro ($20/mes)**.
- Estimado real: ~$25-40/mes dependiendo de volumen de ejecuciones de `performance-analyst-72h` (cada hora) y `approval-gatekeeper` (cada 10 min).
- Para reducir costos: `approval-gatekeeper` puede subir a `*/30 * * * *` si la operación tolera latencia.
