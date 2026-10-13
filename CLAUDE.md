# CLAUDE.md — Marketing Agents Toolkit v2.1

**Toolkit multi-tenant de automatización de marketing para Claude Code.** Cubre el flujo completo de agencia (6 fases) para clientes **B2B, B2C y both** — nada hardcoded, todo se adapta a `brief.company.business_model`.

---

## ¿Qué es este toolkit?

Un **plugin de Claude Code** compuesto por:
- **14 agentes** especializados (bounded contexts) que operan vía Task tool
- **25 commands** (slash commands) como entry points thin
- **27 skills** reutilizables (atómicos y composables)
- **3 schemas** JSON como contratos entre componentes

Instalable en cualquier repo via `install.sh`. Cada repo tiene su propio `.claude/client-brief.json` que define el cliente — **el toolkit no se modifica entre clientes, solo el brief**.

### Qué cambia según `business_model` del brief

| Dimensión | B2B | B2C | Both |
|---|---|---|---|
| Tono del contenido | Profesional, data-driven | Conversacional, aspiracional | Mezcla según pilar |
| Pilares dominantes | Educativo + Casos de éxito | Lifestyle + Entretenimiento | 60/40 según foco |
| Formatos ganadores | Carousels + LinkedIn long-form | Reels + Stories + UGC | Alternancia |
| Plataformas priorizadas | LinkedIn + IG empresarial | IG + TikTok + Facebook | Todas |
| `/prospect-leads` disponible | ✅ Sí | ❌ No (es wholesale) | ✅ Sí |
| ICP requerido en brief | ✅ Sí | ❌ Opcional | ✅ Recomendado |

### Cadencia dinámica (no asumida)

Para cada red del brief, puedes elegir:
- `cadence_strategy: "manual"` → tú defines `frequency_per_week` y `preferred_times`
- `cadence_strategy: "ai-recommended"` → el `content-planner` propone cadencia óptima basada en objetivos, buyer_persona, budget, audit y benchmarks del sector, con aprobación humana.

**Principio clave**: no asumimos "daily publishing". La cadencia emerge de la estrategia. Un cliente de retención B2B puede publicar 2×/semana; uno de awareness B2C con buen budget puede publicar 2×/día. El planner calcula, el humano aprueba.

---

## Arquitectura

```
┌──────────────────────────────────────────────────────────┐
│  REPO DEL CLIENTE                                         │
│  .claude/client-brief.json   .claude/brand-kit.json       │
│  .claude/state/              .env                         │
└──────────────────────────────────────────────────────────┘
                             │
                             ↓ /command (slash)
┌──────────────────────────────────────────────────────────┐
│  LAYER 1 — COMMANDS (thin orchestrators, 24)              │
│  Entry points. Validan, delegan al agente, presentan.    │
└──────────────────────────────────────────────────────────┘
                             │
                             ↓ Task tool (subagent)
┌──────────────────────────────────────────────────────────┐
│  LAYER 2 — AGENTS (bounded contexts, 13)                  │
│  Cognición especializada por dominio. Decisiones.        │
└──────────────────────────────────────────────────────────┘
                             │
                             ↓ invoca
┌──────────────────────────────────────────────────────────┐
│  LAYER 3 — SKILLS (operaciones atómicas, 27)              │
│  _core/ (6)  publishing/ (9)  social_monitoring/ (2)     │
│  market_intelligence/ (2)  prospecting/ (5)  otros (3)   │
└──────────────────────────────────────────────────────────┘
                             │
                             ↓ APIs
┌──────────────────────────────────────────────────────────┐
│  LAYER 4 — EXTERNAL                                       │
│  Meta Graph, TikTok, Telegram, fal.ai, Anthropic         │
└──────────────────────────────────────────────────────────┘
```

**Reglas de oro**:
1. Un command NO razona — delega al agente correcto.
2. Un agente NO publica directo a API — delega al skill.
3. Un skill NO toma decisiones estratégicas — ejecuta operación acotada.
4. Comunicación entre agentes = archivos JSON en `.claude/state/` con schema versionado (ver `skills/_core/schemas/state-structure.md`).

---

## El flujo de agencia (6 fases)

Cubierto 100% por el toolkit:

### Phase 1 — Diagnóstico y estrategia
| Qué hace una agencia | Toolkit lo hace via |
|---|---|
| Brief con cliente (negocio, ICP, presupuesto, KPIs) | `/briefing new` (schema v2.0) |
| Auditoría de cuentas actuales + competencia | `/audit` → `account-auditor` |
| Buyer persona | Capturado en `/briefing` |
| Objetivos y KPIs medibles | `brief.kpis` + `.claude/state/kpi-tracking.json` |
| Rol de cada red | `brief.network_roles` |

### Phase 2 — Marca
| Qué hace una agencia | Toolkit lo hace via |
|---|---|
| Plataforma de marca (voz, propuesta) | Capturado en `/briefing` + `brand-kit` |
| Identidad visual (logo, paleta, tipografías) | `/brand-kit new` → `brand-guardian` |
| Manual + plantillas | `brand-kit.json` + prompt_injection auto en todo contenido |
| Optimización de perfiles | `/optimize-profiles` → skill `optimize-profile` |

### Phase 3 — Planeación de contenido (mensual)
| Qué hace una agencia | Toolkit lo hace via |
|---|---|
| Pilares de contenido | Automático en `content-planner` |
| Parrilla con copy/hashtags/CTA/responsable | `/content-calendar` → `content-planner` |
| Frecuencia por red | De `brief.network_roles` |
| Aprobación del cliente | `_core/telegram-approval` |

### Phase 4 — Producción
| Qué hace una agencia | Toolkit lo hace via |
|---|---|
| Pre-producción (guiones, shot lists) | `/production-plan` → `producer` |
| Sesión por lotes mensual | `producer` agrupa por tipo/locación |
| Call sheets por día | `producer` genera call sheets |
| Specs de post-producción | `producer` genera edit specs |
| Segunda aprobación de pieza final | `_core/telegram-approval` desde publisher |

### Phase 5 — Publicación, comunidad y pauta
| Qué hace una agencia | Toolkit lo hace via |
|---|---|
| Programación de posts | `/publish-today` → `content-publisher` |
| Gestión de comunidad (comments/DMs) | `/community` → `community-manager` con FAQ + SLA |
| Pauta Meta Ads + TikTok Ads | `/ads` → `paid-media` (nunca gasta sin aprobación humana) |
| Colaboraciones / UGC | (manual, no automatizado aún) |

### Phase 6 — Monitoreo y optimización
| Qué hace una agencia | Toolkit lo hace via |
|---|---|
| Métricas 24-72h por pieza | `performance-analyst` (modo `post-24h`, `post-72h`) |
| Seguimiento semanal | `performance-analyst` (modo `weekly`) + `social-monitor` nocturno |
| Informe mensual vs KPIs | `/report-monthly` → `performance-analyst` |
| Retroalimentación al mes siguiente | Evento `performance_insight` → `content-planner` siguiente ciclo |

---

## Los 14 agentes

| Agente | Fase | Modelo | Responsabilidad | Adaptativo a business_model |
|---|---|---|---|---|
| `account-auditor` | 1 | opus | Audita cuentas + competencia, valida realismo de KPIs | ✅ |
| `brand-guardian` | 2 | opus | Extrae identidad visual/verbal del cliente | ✅ |
| `content-planner` | 3 | opus | Parrilla mensual + calibración de cadencia óptima | ✅ |
| `trend-analyst` | 3 | sonnet | Analiza tendencias virales YouTube + TikTok, genera ideas | ✅ |
| `producer` | 4 | opus | Plan de rodaje batch mensual | ✅ |
| `content-publisher` | 5 | opus | Publica contenido multi-plataforma | ✅ |
| `community-manager` | 5 | sonnet | Comments/DMs con FAQ + SLA + escalación | ✅ |
| `paid-media` | 5 | opus | Meta Ads + TikTok Ads (nunca gasta solo) | ✅ |
| `social-monitor` | 6 | sonnet | Reporte nocturno + detección crisis + token health | — (neutral) |
| `performance-analyst` | 6 | opus | Análisis 24h/72h/semanal/mensual vs KPIs | — (neutral) |
| `conductor` | cross | opus | Orquestación meta — eventos, circuit breakers, flujo diario | — (neutral) |
| `approval-gatekeeper` | infra | sonnet | Gestión asíncrona de aprobaciones humanas | — (neutral) |
| `market-analyst` | aux | opus | Inteligencia de mercado (precios + competencia pública) | — (neutral) |
| `sales-prospector` | aux B2B | opus | **Solo B2B o both** — pipeline comercial wholesale/empresas | B2B-only |

---

## Los 24 commands

### Flujo diario / orquestación (6)
- `/daily` — flujo completo del día (reemplaza ejecutar múltiples manuales)
- `/dashboard` — vista ejecutiva consolidada
- `/pause-posting` + `/resume-posting` — circuit breakers manuales
- `/check-approvals` — procesar aprobaciones Telegram pendientes
- `/retry-failed` — recuperar operaciones fallidas

### Phase 1 — Diagnóstico (2)
- `/briefing new|update|show|validate` — brief del cliente
- `/audit` — auditoría de cuentas + competencia

### Phase 2 — Marca (2)
- `/brand-kit new|update|show` — identidad visual y verbal
- `/optimize-profiles` — optimizar bios, links, destacadas

### Phase 3 — Planeación (2)
- `/content-calendar` — parrilla mensual
- `/trend-ranking` — ideas de contenido basadas en virales de YouTube + TikTok

### Phase 4 — Producción (1)
- `/production-plan` — plan de rodaje batch

### Phase 5 — Publicación (4)
- `/publish-today` — publicar contenido del día
- `/community` — gestión conversacional
- `/ads` — pauta digital
- `/respond-comments` — responder comentarios específicos

### Phase 6 — Monitoreo (3)
- `/social-report` — reporte nocturno
- `/report-monthly` — informe mensual vs KPIs
- `/market-intel` — inteligencia de mercado

### Auxiliares B2B (2)
- `/prospect-leads` — búsqueda y calificación
- `/followup-leads` — secuencia de seguimiento

### Infraestructura (3)
- `/setup-check` — validación de credenciales
- `/setup-railway` — despliegue como cron jobs
- `/security-audit` — auditoría de seguridad

---

## Multi-tenancy — cómo funciona

```
cualquier-repo-cliente/
├── .claude/
│   ├── client-brief.json          ← datos del cliente (v2.0)
│   ├── brand-kit.json             ← identidad visual
│   ├── brand-images/              ← fotos, logos
│   ├── commands/ agents/ skills/  ← toolkit instalado
│   └── state/                     ← estado operacional
│       ├── calendar/ posts/ drafts/ approvals/
│       ├── reports/ intel/ leads/ followups/
│       ├── audits/ community/ ads/ performance/
│       ├── production/ dashboards/
│       ├── locks/ handoffs/ logs/
│       └── insights/              ← feedback loop al planner
├── .env                           ← credenciales (gitignored)
└── CLAUDE.md                      ← mínimo generado por install
```

El toolkit **nunca se modifica** entre clientes. Todo cambia vía:
- `client-brief.json` (configuración de negocio)
- `brand-kit.json` (identidad)
- `.env` (credenciales)

Para instalar en otro repo: `bash install.sh /ruta/al/repo-cliente`

---

## Feedback loop fundamental

Lo que convierte el toolkit en **sistema que aprende**:

```
1. content-publisher publica  → emite post_published
2. performance-analyst 24h/72h → emite post_candidate_for_boost (si gana)
3. performance-analyst mensual → emite performance_insight
4. conductor acumula insights en state/insights/pending-for-planner.json
5. content-planner siguiente ciclo lee insights + ajusta parrilla
6. Loop vuelve a 1 con parrilla optimizada
```

Y los otros loops:
- `account-auditor` → `kpi_adjustment_needed` → humano ajusta brief
- `performance-analyst` → `campaign_underperforming` → `paid-media` optimiza
- `social-monitor`/`community-manager` → `crisis_detected` → `conductor` pausa publisher

---

## Repo del toolkit (este)

```
Marketing_agents/
├── commands/                       ← 24 slash commands
├── agents/                         ← 13 subagentes con frontmatter YAML
├── skills/
│   ├── _core/                      ← 6 skills fundacionales + 4 schemas
│   │   ├── schemas/
│   │   │   ├── client-brief.schema.json  (v2.0 con objectives, kpis, budget, persona, roles)
│   │   │   ├── brand-kit.schema.json
│   │   │   ├── kpi-tracking.schema.json
│   │   │   └── state-structure.md  ← taxonomía de 23 eventos handoff
│   │   ├── load-brief.md
│   │   ├── load-brand-kit.md
│   │   ├── state-store.md          ← idempotency, locks, events
│   │   ├── telegram-approval.md
│   │   ├── telegram-notify.md
│   │   └── preflight-check.md
│   ├── publishing/ (9)
│   ├── social_monitoring/ (2)
│   ├── market_intelligence/ (2)
│   ├── prospecting/ (5)
│   ├── deployment/ (1)
│   └── security/ (1)
├── demo/                           ← FastAPI web para probar sin APIs reales
├── install.sh                      ← instalador multi-tenant
├── plugin.json
├── .claude-plugin/plugin.json      ← manifest oficial
└── CLAUDE.md                       ← este archivo
```

---

## Comandos recomendados por fase

### Onboarding de cliente nuevo (día 1)
```
1. /briefing new          # 10-15 min, captura todo el brief v2.0
2. /setup-check           # validar credenciales
3. /audit                 # baseline real de cuentas (ajusta KPIs irreales)
4. /brand-kit new         # extraer identidad visual
5. /optimize-profiles     # bios/links alineados con objetivos
```

### Operación mensual
```
Día 20: /production-plan     # plan de rodaje del próximo mes
Día 25: /content-calendar    # parrilla del próximo mes
Día 1 : /report-monthly      # informe del mes anterior (incluye KPIs, feedback)
```

### Operación diaria (automatizar con Railway cron)
```
/daily                 # publisher + community + monitor según hora/día
```

Si prefieres control granular:
```
Mañana : /publish-today
Cada 4h: /community
Noche  : /social-report
Lunes  : /market-intel + /dashboard
```

### Pausas y recuperación
```
/pause-posting "razón"        # circuit breaker manual
/resume-posting                # levantar
/retry-failed --dry-run        # ver qué quedó pendiente
/retry-failed                  # reintentar lo recuperable
```

---

## Modelos por tarea

- **Generación creativa / estratégica**: `claude-opus-4-7` + thinking adaptivo
- **Análisis / síntesis / clasificación**: `claude-sonnet-4-6`
- **Validaciones / API calls simples**: `claude-haiku-4-5`

Cada skill y agente declara su modelo en el frontmatter YAML.

---

## Instalación

### En un repo nuevo

```bash
cd /ruta/al/repo-del-cliente
bash <(curl -sL https://raw.githubusercontent.com/jufaldanabo/Marketing_agents/main/install.sh)
```

### Desde el toolkit clonado (dev)

```bash
cd ~/Documents/Repos\ github/Marketing_agents
bash install.sh /ruta/al/repo-del-cliente
```

### Después de instalar

1. Copia `.env.example` → `.env` y rellena credenciales
2. Abre Claude Code en el repo del cliente
3. `/briefing new` → captura el brief
4. `/setup-check` → valida que todo funcione
5. `/audit` → baseline real

---

## Convenciones del toolkit

- Archivos `.md` son **artefactos primarios** (no hay código Python en el toolkit — solo en `demo/`)
- Frontmatter YAML en todo skill y agente (name, description, allowed-tools, model)
- Idempotency keys SHA1 en operaciones destructivas (ver `_core/state-store`)
- Events con schema versionado para interoperabilidad entre agentes (ver `state-structure.md`)
- Comunicación con humano: siempre vía `_core/telegram-approval` (síncrono) o `_core/telegram-notify` (fire-and-forget)
- Idioma del toolkit: inglés en nombres, español en descripciones/system prompts (el cliente final habla español)

---

## Scope y limitaciones

### Lo que el toolkit SÍ hace
- Captura brief completo con objetivos + KPIs + presupuesto + persona
- Audita cuentas actuales + competencia
- Extrae identidad de marca de materiales reales
- Planea parrillas mensuales con razonamiento estratégico
- Produce dossier completo de rodaje batch
- Publica en IG/FB/TikTok con aprobación humana
- Gestiona comunidad con FAQ + SLA
- Diseña campañas de pauta (instrucciones ejecutables, no auto-gasto)
- Monitorea comentarios/métricas con alertas
- Analiza performance vs KPIs y cierra feedback loop
- Prospecta leads B2B (auxiliar)

### Lo que el toolkit NO hace
- No graba video ni toma fotos (planifica, humano ejecuta)
- No edita video / retoca fotos (produce specs)
- No gasta en pauta sin aprobación humana explícita
- No modifica bio/perfiles automáticamente (APIs no lo permiten)
- No garantiza resultados — probabilístico como todo marketing

---

*Toolkit v2.0 | Última actualización: refactor completo 2026-10 | Alineado con flujo de agencia de 6 fases*
