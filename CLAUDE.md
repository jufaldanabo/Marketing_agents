# CLAUDE.md — Digital Marketing Agents Toolkit

Este archivo describe el toolkit de Claude Code para agentes de marketing digital.
Es un repositorio de **skills, commands y agentes** listos para instalarse en proyectos de empresa.

---

## ¿Qué es este toolkit?

Un conjunto de archivos `.md` que definen comportamientos reutilizables para Claude Code.
Al copiar estos archivos a un proyecto de empresa, Claude puede ejecutar flujos completos
de marketing en redes sociales sin configuración adicional.

## Estructura del toolkit

```
Marketing_agents/                       ← Este repositorio (el toolkit)
│
├── commands/                           ← Slash commands (/publish-today, etc.)
│   ├── publish-today.md               → /publish-today        — Genera y publica contenido B2B diario
│   ├── social-report.md               → /social-report        — Reporte nocturno de métricas y comentarios
│   ├── market-intel.md                → /market-intel         — Informe de precios y competidores
│   ├── prospect-leads.md             → /prospect-leads       — Busca y califica clientes potenciales
│   ├── respond-comments.md           → /respond-comments     — Genera y publica respuestas a comentarios
│   ├── followup-leads.md             → /followup-leads       — Seguimiento multi-toque a leads sin respuesta
│   ├── check-approvals.md            → /check-approvals      — Publica borradores aprobados via Telegram
│   ├── setup-check.md                → /setup-check          — Valida credenciales y conexiones
│   ├── setup-railway.md              → /setup-railway        — Configura despliegue automático en Railway
│   └── security-audit.md             → /security-audit       — Audita seguridad antes de desplegar
│
├── agents/                             ← System prompts completos de cada agente
│   ├── publisher-agent.md             → Agente Publicador (Instagram + Facebook)
│   ├── monitoring-agent.md            → Agente de Monitoreo Social (Telegram)
│   ├── intelligence-agent.md         → Agente de Inteligencia de Mercado
│   └── prospecting-agent.md          → Agente de Prospección B2B
│
└── skills/                             ← Bloques reutilizables (building blocks)
    ├── publishing/
    │   ├── generate-b2b-content.md   → Genera texto B2B adaptado por plataforma
    │   ├── publish-instagram.md      → Publica en Instagram Graph API
    │   ├── publish-facebook.md       → Publica en Facebook Graph API
    │   ├── generate-image-prompt.md  → Genera prompts para Midjourney/DALL-E/Firefly
    │   ├── generate-tiktok-content.md → Genera guión de video + caption de foto para TikTok
    │   ├── publish-tiktok.md         → Publica en TikTok Content Posting API
    │   └── content-approval.md       → Envía borrador a Telegram para aprobación del manager
    ├── social_monitoring/
    │   ├── send-telegram.md          → Envía reportes y alertas por Telegram Bot
    │   ├── respond-comments.md       → Clasifica y genera respuestas a comentarios
    │   └── check-token-expiry.md     → Verifica vencimiento de tokens Meta y alerta
    ├── market_intelligence/
    │   ├── monitor-prices.md         → Monitorea precios de materias primas
    │   └── track-competitors.md      → Rastrea actividad pública de competidores
    ├── prospecting/
    │   ├── search-leads.md           → Busca empresas que coincidan con el ICP
    │   ├── qualify-leads.md          → Califica y puntúa cada lead (0-100)
    │   ├── outreach-message.md       → Genera mensajes de primer contacto personalizados
    │   ├── follow-up-sequence.md     → Genera secuencia de seguimiento para leads sin respuesta
    │   └── handle-positive-response.md → Gestiona respuesta positiva: mensaje + notificación
    ├── deployment/
    │   └── schedule-railway.md       → Despliega agentes como cron jobs en Railway
    └── security/
        └── validate-security.md      → Valida reglas de seguridad y buenas prácticas
```

---

## Cómo instalar en un proyecto de empresa

### Opción A — Copiar commands (recomendado)
```bash
# Copia los slash commands al proyecto de la empresa
cp commands/*.md /ruta/al/proyecto-empresa/.claude/commands/

# Luego desde Claude Code en ese proyecto:
# /publish-today
# /social-report
# /market-intel
```

### Opción B — Referenciar skills desde CLAUDE.md
En el `CLAUDE.md` del proyecto de empresa, agrega:
```markdown
## Skills disponibles
Ver toolkit: /ruta/al/Marketing_agents/skills/
```

### Opción C — Git submodule
```bash
git submodule add https://github.com/usuario/Marketing_agents .claude/marketing-toolkit
```

---

## Variables de configuración por empresa

Cada command/skill usa estas variables (se definen en el `.env` del proyecto empresa):

| Variable | Agentes que la usan | Descripción |
|---|---|---|
| `ANTHROPIC_API_KEY` | Todos | API key de Anthropic |
| `COMPANY_NAME` | Todos | Nombre de la empresa |
| `INDUSTRY` | Todos | Sector industrial (ej. textil, manufactura) |
| `INSTAGRAM_ACCESS_TOKEN` | Publicador, Monitoreo | Token de acceso Instagram Graph API |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | Publicador, Monitoreo | ID de cuenta de negocio Instagram |
| `FACEBOOK_ACCESS_TOKEN` | Publicador, Monitoreo | Token de página de Facebook |
| `FACEBOOK_PAGE_ID` | Publicador, Monitoreo | ID de la página de Facebook |
| `TELEGRAM_BOT_TOKEN` | Monitoreo, Intel, Prospección | Token del bot de Telegram |
| `TELEGRAM_CHAT_ID` | Monitoreo, Intel, Prospección | Chat ID donde enviar reportes |
| `COMMODITIES` | Inteligencia | Lista de materias primas a monitorear |
| `COMPETITORS` | Inteligencia | Lista de competidores a rastrear |
| `PRODUCT` | Prospección | Producto/servicio que vende la empresa |
| `INDUSTRY_TARGET` | Prospección | Sector de los clientes objetivo |
| `GEOGRAPHY` | Prospección | País o región objetivo de ventas |
| `SENDER_NAME` | Prospección | Nombre del vendedor que contactará |
| `SENDER_ROLE` | Prospección | Cargo del vendedor |

---

## Agentes del toolkit

### 1. Agente Publicador
- **Tarea**: Genera contenido B2B diario y publica en Instagram y Facebook
- **Cuándo corre**: Diariamente (mañana)
- **Archivo**: `agents/publisher-agent.md`
- **Command**: `/publish-today`

### 2. Agente de Monitoreo Social
- **Tarea**: Revisa comentarios, mensajes y métricas; notifica por Telegram
- **Cuándo corre**: Noche (automático)
- **Archivo**: `agents/monitoring-agent.md`
- **Commands**: `/social-report`, `/respond-comments`

### 3. Agente de Inteligencia de Mercado
- **Tarea**: Monitorea precios de materias primas y actividad de competidores
- **Cuándo corre**: Semanal o bajo demanda
- **Archivo**: `agents/intelligence-agent.md`
- **Command**: `/market-intel`

### 4. Agente de Prospección B2B
- **Tarea**: Busca, califica y prepara el primer contacto con clientes potenciales
- **Cuándo corre**: Bajo demanda o semanal
- **Archivo**: `agents/prospecting-agent.md`
- **Commands**: `/prospect-leads`, `/followup-leads`

---

## Convenciones del toolkit

- Los archivos `.md` son los **artefactos principales** — no hay código Python en este repo
- Cada skill es **autocontenido**: describe qué hacer, cómo hacerlo y qué devolver
- Los commands son **ejecutables directamente** desde Claude Code con `/nombre-command`
- Los agentes son **system prompts** completos listos para usar con la API de Claude

## Modelo de IA por defecto

- **Generación de contenido**: `claude-opus-4-6` (máxima calidad)
- **Tareas de monitoreo**: `claude-sonnet-4-6` (balance velocidad/costo)
- **Clasificación simple**: `claude-haiku-4-5` (rápido y económico)

---

*Toolkit iniciado: febrero 2026 | Idioma de código: inglés | Comunicación: español*
