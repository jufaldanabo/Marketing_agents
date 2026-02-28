# Digital Marketing Agents Toolkit

Toolkit de Claude Code para crear agentes de marketing B2B en redes sociales.
Contiene **skills**, **commands** y **agentes** listos para instalar en proyectos de empresa.

## ¿Qué incluye?

| Tipo | Archivos | Para qué sirven |
|---|---|---|
| **Commands** | `commands/*.md` | Slash commands ejecutables (`/publish-today`, etc.) |
| **Agents** | `agents/*.md` | System prompts completos de cada agente |
| **Skills** | `skills/**/*.md` | Building blocks reutilizables por los agentes |

## Instalación en un proyecto de empresa

### Paso 1 — Clonar o copiar el toolkit

```bash
# Opción A: como submodule
git submodule add https://github.com/usuario/Marketing_agents .claude/marketing-toolkit

# Opción B: copiar directo
cp -r Marketing_agents/commands/* /proyecto-empresa/.claude/commands/
```

### Paso 2 — Configurar variables de entorno

Crea un `.env` en el proyecto de la empresa:

```env
ANTHROPIC_API_KEY=sk-ant-...

# Instagram Graph API
INSTAGRAM_ACCESS_TOKEN=...
INSTAGRAM_BUSINESS_ACCOUNT_ID=...

# Facebook Graph API
FACEBOOK_ACCESS_TOKEN=...
FACEBOOK_PAGE_ID=...
FACEBOOK_APP_ID=...        # Necesario para verificar vencimiento de tokens
FACEBOOK_APP_SECRET=...    # Necesario para verificar vencimiento de tokens

# TikTok Content Posting API (opcional)
TIKTOK_ACCESS_TOKEN=...    # Token OAuth 2.0 con scope video.publish
TIKTOK_OPEN_ID=...         # open_id del usuario (se obtiene en el auth flow)
# Para obtener estas credenciales: https://developers.tiktok.com/
# → Crear app → Product: "Content Posting API" → scope: video.publish

# Telegram (para reportes)
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...

# Configuración de la empresa
COMPANY_NAME=Mi Empresa S.A.
INDUSTRY=textil
DEFAULT_TONE=professional
COMMODITIES=algodón,poliéster,lana
COMPETITORS=Empresa A,empresa-b.com
```

### Paso 3 — Referenciar en CLAUDE.md del proyecto

En el `CLAUDE.md` del proyecto de empresa, agregar:

```markdown
## Marketing Toolkit instalado

Commands disponibles:
- `/publish-today` — Genera y publica contenido B2B diario
- `/social-report` — Reporte nocturno de métricas y comentarios
- `/market-intel` — Informe de inteligencia de mercado
- `/prospect-leads` — Busca y califica clientes potenciales
- `/respond-comments` — Genera y publica respuestas a comentarios
- `/followup-leads` — Seguimiento a leads que no respondieron

Configuración:
- Empresa: {COMPANY_NAME}
- Sector: {INDUSTRY}
- Tono de marca: {TONE}
```

### Paso 4 — Usar desde Claude Code

```bash
# En la terminal de Claude Code del proyecto empresa:
/setup-check      # Primero: validar que todas las credenciales funcionan
/publish-today
/social-report
/market-intel
/prospect-leads
/respond-comments
/followup-leads
/check-approvals  # Publicar borradores aprobados por el manager en Telegram
/setup-railway    # Configura despliegue automático en Railway
```

---

## Commands disponibles

### `/publish-today`
Genera contenido B2B y publica en Instagram y Facebook.
- Pide el tema si no se especifica
- Muestra preview antes de publicar
- Guarda historial en `.claude/posts/`

### `/social-report`
Reporte nocturno de actividad en redes sociales.
- Lee comentarios, DMs y métricas de Instagram y Facebook
- Analiza con Claude y prioriza por urgencia
- Envía resumen por Telegram
- Guarda reporte en `.claude/reports/`

### `/market-intel`
Informe de inteligencia competitiva.
- Busca precios actuales de materias primas
- Rastrea actividad pública de competidores
- Genera informe estratégico accionable
- Guarda en `.claude/intel/`

### `/prospect-leads`
Búsqueda y calificación de clientes potenciales B2B.
- Define el Ideal Customer Profile (ICP) con el usuario
- Busca empresas candidatas con WebSearch y WebFetch (fuentes públicas)
- Califica cada lead con score 0-100 (ajuste de perfil + intención de compra + accesibilidad)
- Genera mensajes de primer contacto personalizados para LinkedIn o email
- Guarda lista en `.claude/leads/`

### `/respond-comments`
Responde comentarios pendientes en Instagram y Facebook.
- Lee comentarios del reporte nocturno o consulta la API directamente
- Clasifica cada comentario: comercial, técnico, positivo, negativo, spam
- Genera respuesta pública (máx 4 líneas) + DM de seguimiento si aplica
- Muestra preview y solicita aprobación antes de publicar
- Escala automáticamente comentarios de alto riesgo o influencers
- Guarda respuestas publicadas en `.claude/responses/`

### `/followup-leads`
Seguimiento multi-toque a leads que no respondieron al primer contacto.
- Revisa el historial de leads y calcula qué etapa corresponde (1/2/3/break-up)
- Genera mensajes de seguimiento con ángulo diferente en cada etapa
- Etapa 1: Agrega valor (dato del sector), Etapa 2: Cambia ángulo, Etapa 3: Urgencia contextual, Etapa 4: Break-up elegante
- Cuando un lead responde positivamente: genera mensaje de seguimiento + notifica al vendedor
- Copia mensajes al portapapeles para envío manual (LinkedIn/WhatsApp no tienen API de envío)
- Actualiza `followup-tracking.json` con estado de cada lead

### `/setup-check`
Valida que todas las credenciales y conexiones estén activas antes del primer deploy.
- Prueba Instagram, Facebook, TikTok (si configurado) y Telegram
- Verifica vencimiento de tokens Meta API via `/debug_token`
- Comprueba permisos requeridos en cada cuenta
- Envía mensaje de prueba por Telegram para confirmar configuración
- Muestra reporte ✅/❌ con instrucciones de corrección

### `/check-approvals`
Publica borradores que el manager aprobó via Telegram.
- Lee respuestas del bot de Telegram (aprobar / editar / rechazar)
- Publica automáticamente los borradores aprobados en todas sus plataformas
- Regenera el contenido si el manager pidió cambios
- Programa ejecución cada 30 minutos en Railway

---

## Agentes incluidos

| Agente | Archivo | Modelo | Frecuencia |
|---|---|---|---|
| Publisher Agent | `agents/publisher-agent.md` | `claude-opus-4-6` | Diario |
| Social Monitoring Agent | `agents/monitoring-agent.md` | `claude-sonnet-4-6` | Noche |
| Market Intelligence Agent | `agents/intelligence-agent.md` | `claude-opus-4-6` | Semanal |

---

## Skills disponibles

### Publishing
- `generate-b2b-content.md` — Genera texto B2B para Instagram y Facebook
- `publish-instagram.md` — Publica en Instagram Graph API
- `publish-facebook.md` — Publica en Facebook Graph API
- `generate-image-prompt.md` — Genera prompts para Midjourney, DALL-E, Firefly o Stable Diffusion
- `generate-tiktok-content.md` — Genera guión de video (15-60 seg) + caption de foto para TikTok
- `publish-tiktok.md` — Publica en TikTok Content Posting API (foto automático, video con archivo)
- `content-approval.md` — Guarda borrador y lo envía a Telegram para aprobación del manager

### Social Monitoring
- `send-telegram.md` — Envía reportes y alertas por Telegram
- `respond-comments.md` — Clasifica comentarios y genera respuestas personalizadas
- `check-token-expiry.md` — Verifica vencimiento de tokens Meta y envía alerta preventiva

### Market Intelligence
- `monitor-prices.md` — Busca precios de materias primas (WebSearch)
- `track-competitors.md` — Rastrea actividad pública de competidores

### Prospecting
- `search-leads.md` — Busca empresas que coincidan con el ICP
- `qualify-leads.md` — Califica y puntúa cada lead (0-100)
- `outreach-message.md` — Genera mensajes de primer contacto personalizados
- `follow-up-sequence.md` — Genera secuencia de seguimiento multi-toque (4 etapas)
- `handle-positive-response.md` — Clasifica respuesta positiva, genera siguiente mensaje y notifica al vendedor

### Deployment
- `schedule-railway.md` — Genera scheduler Python + railway.toml para cron jobs automáticos

### Security
- `validate-security.md` — 18 reglas con ejemplos ✅/❌ para Meta API, Anthropic API, scraping y Telegram

---

## Cómo agregar este toolkit a un nuevo cliente

1. Crear repositorio del cliente: `mi-cliente/`
2. Agregar este repo como submodule: `.claude/marketing-toolkit/`
3. Copiar los commands a `.claude/commands/`
4. Configurar `.env` con credenciales del cliente
5. Actualizar `CLAUDE.md` con datos del cliente (empresa, sector, tono)
6. Ejecutar `/security-audit --pre-deploy` antes del primer despliegue
7. Probar con `/publish-today` en modo dry-run primero

---

## Estructura del repositorio

```
Marketing_agents/
├── README.md                              ← Este archivo
├── CLAUDE.md                              ← Contexto para Claude Code
│
├── commands/                              ← Slash commands ejecutables
│   ├── publish-today.md                  → /publish-today
│   ├── social-report.md                  → /social-report
│   ├── market-intel.md                   → /market-intel
│   ├── prospect-leads.md                 → /prospect-leads
│   ├── respond-comments.md               → /respond-comments
│   ├── followup-leads.md                 → /followup-leads
│   ├── setup-railway.md                  → /setup-railway
│   └── security-audit.md                 → /security-audit
│
├── agents/                                ← System prompts de agentes
│   ├── publisher-agent.md
│   ├── monitoring-agent.md
│   ├── intelligence-agent.md
│   └── prospecting-agent.md
│
└── skills/                                ← Building blocks reutilizables
    ├── publishing/
    │   ├── generate-b2b-content.md
    │   ├── publish-instagram.md
    │   ├── publish-facebook.md
    │   └── generate-image-prompt.md
    ├── social_monitoring/
    │   ├── send-telegram.md
    │   └── respond-comments.md
    ├── market_intelligence/
    │   ├── monitor-prices.md
    │   └── track-competitors.md
    ├── prospecting/
    │   ├── search-leads.md
    │   ├── qualify-leads.md
    │   ├── outreach-message.md
    │   └── follow-up-sequence.md
    └── deployment/
        └── schedule-railway.md
```

---

*Digital Marketing Agents Toolkit — febrero 2026*
