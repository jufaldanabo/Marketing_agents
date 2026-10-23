---
description: Captura o actualiza el brief estratégico del cliente — empresa, objetivos de negocio, KPIs, presupuesto, buyer persona, ICP, mercado, catálogo, roles por red. Es el documento fundacional de las 6 fases del flujo de agencia.
argument-hint: new | update | show | validate [sección]
allowed-tools: [Read, Write, Edit, Bash, Task]
---

# Command: /briefing

**Propósito**: Entry point para gestionar `client-brief.json` v2.0 — el documento fundacional que todo el toolkit lee como contexto del cliente.

**Alineación con el flujo de agencia**: Captura las dimensiones de **Phase 1 — Diagnóstico y estrategia** del flujo real:
- Objetivos de negocio (ventas, leads, awareness)
- Presupuesto
- KPIs medibles con baseline y target
- Buyer persona
- Rol de cada red social

**Schema**: `skills/_core/schemas/client-brief.schema.json` (v2.0)

---

## Subacciones

| Acción | Uso |
|---|---|
| `/briefing new` | Flujo guiado completo (10-15 min) |
| `/briefing update [sección]` | Actualizar una sección específica |
| `/briefing show` | Mostrar brief activo + completitud |
| `/briefing validate` | Verificar que esté listo para operar |

**Secciones actualizables con `update`**:
`company` · `objectives` · `kpis` · `budget` · `network_roles` · `buyer_persona` · `icp` · `market` · `sales` · `catalog` · `credentials_status`

Sin argumento → si existe brief, `show`; si no, sugerir `new`.

---

## Acción: `new` — Flujo guiado completo

### Precondiciones

Si existe `.claude/client-brief.json`:
```
Ya existe un brief para "{brand_name}". ¿Qué quieres hacer?
  1. Reemplazar completamente (perderás el actual)
  2. Actualizar secciones específicas → /briefing update
  3. Cancelar
```

### Introducción

```
¡Hola! Soy el asistente que arma el brief de tu cliente.

Un brief completo captura:
  📌 Empresa, modelo de negocio, producto, tono y plataformas
  🎯 Objetivos de negocio y KPIs medibles
  💰 Presupuesto para pauta y producción
  👤 Buyer persona (el humano que decide)
  🏢 ICP (si es B2B o both)
  📊 Mercado y competencia
  🎨 Rol estratégico de cada red (cadencia manual o AI-recomendada)

Me tomará 10-15 minutos. Puedes responder informalmente — yo estructuro.
```

### Fase 1 — Empresa (sección `company`)

**1.1 Identidad**:
- Nombre y sector
- Qué vende/produce
- Ciudad y país
- Propuesta de valor (¿por qué eligen a este cliente?)
- Misión/propósito (opcional, en una frase)

**1.2 Modelo de negocio** ⚠️ **CRÍTICO — determina todo el tono downstream**:
```
¿A quién le vende el cliente?

  1. B2C — Consumidor final (ej. zapatos a usuario, panadería a familias,
     ropa a consumidor, cualquier producto/servicio a persona natural)
  2. B2B — Empresas / tomadores de decisión (ej. maquinaria industrial a
     fabricantes, software empresarial, materia prima a confeccionistas)
  3. Both — Vende a ambos (ej. retailer con línea mayorista, consultoría
     que atiende empresas y personas)
```

**Impacto de la respuesta**:
- `b2c` → tono conversacional, aspiracional, lifestyle. ICP opcional, buyer_persona crítico.
- `b2b` → tono profesional, educativo, orientado a decisión. ICP + buyer_persona ambos críticos. Habilita `/prospect-leads`.
- `both` → el content-planner balanceará contenido 70/30 según foco actual (configurable).

**1.3 Tono de comunicación**:
- Formal / Cercano / Técnico / Aspiracional / Otro

**1.4 Plataformas activas**:
- Instagram / Facebook / TikTok / LinkedIn / YouTube

> **Nota**: Si cliente es B2B, LinkedIn suele ser crítico. Si es B2C, TikTok y Instagram
> suelen dominar. El content-planner lo tomará en cuenta.

### Fase 2 — Objetivos de negocio (sección `objectives`) **NUEVO**

**2.1 Objetivo primario (elegir uno)**:
```
¿Cuál es el objetivo principal del cliente en los próximos meses?

  1. Ventas directas (conversión en el canal)
  2. Leads (prospectos para que ventas los cierre)
  3. Awareness (dar a conocer la marca)
  4. Community (crear/consolidar comunidad)
  5. Retention (retener/fidelizar clientes actuales)
  6. Launch (lanzar producto/servicio nuevo)
```

**2.2 Objetivos secundarios** (opcional, hasta 2 más).

**2.3 Horizonte temporal**:
> ¿En cuánto tiempo esperan ver resultados? (típicamente 90 días)

**2.4 Narrativa**:
> Resume el objetivo en una frase estilo "pasar de X a Y en Z días".
> Ejemplos:
> - "Pasar de 20 a 60 leads/mes vía Instagram en 90 días"
> - "Lograr 10K seguidores en TikTok con pauta de $500 USD/mes"
> - "Posicionar la marca como referente del sector en 6 meses"

### Fase 3 — KPIs medibles (sección `kpis`) **NUEVO**

```
Los objetivos solo son útiles si son medibles. Vamos a definir 2-4 KPIs.

Para cada KPI necesito:
  • Qué métrica (ej. 'leads por mes en Instagram')
  • Valor actual (baseline) — si no sabes, decimos 0 o 'no medido'
  • Valor objetivo (target)
  • Deadline (fecha)
  • Dónde se mide (ej. 'Meta Business Suite', 'DMs manuales')
```

Para cada KPI, estructurar como:
```json
{
  "metric": "leads_per_month_instagram",
  "baseline": 20,
  "target": 60,
  "deadline": "2026-09-30",
  "measured_from": "instagram_dms",
  "priority": "primary"
}
```

**Priority**: `primary` (1-2 máx), `secondary` (resto), `tertiary` (nice-to-track).

### Fase 4 — Presupuesto (sección `budget`) **NUEVO**

```
¿Cuánto puede invertir el cliente al mes en marketing digital?

Esta info la usa el agente paid-media para proponer campañas realistas.
Si prefiere no compartir aún, lo dejamos en 0 y lo actualizamos luego.
```

- Moneda (USD, COP, MXN, EUR...)
- Pauta mensual (Meta Ads + TikTok Ads)
- Producción mensual (foto, video, edición)
- Influencers / UGC mensual
- Herramientas (suscripciones)

### Fase 5 — Buyer persona (sección `buyer_persona`) **NUEVO**

> El buyer persona es el **humano que decide la compra**. En B2C es el consumidor final.
> En B2B es el decisor dentro de la empresa objetivo. En ambos casos, define a quién
> le habla el contenido día a día.

```
Dime cómo describirías al cliente ideal:
  • Un nombre ficticio para humanizar (ej. 'María Compras', 'Carlos Decisor')
  • Rango de edad (ej. '35-45')
  • Cargo o rol
  • ¿Qué le duele en su día a día? (3-5 dolores)
  • ¿Qué formatos de contenido consume? (reels, carouseles, podcasts, etc.)
  • ¿Dónde pasa el tiempo? (IG, LinkedIn, WhatsApp, etc.)
  • ¿En qué etapa del journey está? (awareness/consideración/decisión/retención)
  • ¿Qué objeciones típicas tiene? (precio, confianza, tiempo, etc.)
```

### Fase 6 — Rol de cada red social (sección `network_roles`) **NUEVO**

Para cada plataforma de Fase 1.4, capturar el ROL (qué sirve esa red) + ESTRATEGIA DE CADENCIA.

**6.1 Rol estratégico**:
```
¿Cuál es el rol estratégico de {PLATAFORMA} para este cliente?

Guía según business_model:
  B2C:
    Instagram: vitrina + comunidad + ventas directas vía DM
    TikTok: descubrimiento orgánico + reach a nuevo público
    Facebook: pauta pagada + grupos + remarketing a adultos
  B2B:
    LinkedIn: autoridad + thought leadership + lead gen
    Instagram: humanizar la empresa, behind-the-scenes
    YouTube: content largo, casos de estudio
  Both: priorizar según foco del período
```

**6.2 Estrategia de cadencia** ⚠️ **DECISIÓN CLAVE**:
```
¿Cómo definimos frecuencia y horarios en {PLATAFORMA}?

  1. "AI-recommended" (recomendado) — el content-planner analizará:
     • Tu objetivo primario (awareness → más frecuencia; retención → menos)
     • Buyer persona (consumo de formatos)
     • Budget de producción (constraints reales)
     • Benchmarks del sector y business_model
     • Resultados del /audit si existe
     y propondrá frecuencia + horarios óptimos para aprobación.

  2. "Manual" — tú defines explícitamente aquí frequency_per_week y preferred_times.
     El planner los respetará sin cuestionar.
```

**Si elige "AI-recommended"** (default) → guardar `cadence_strategy: "ai-recommended"`.
Primary_formats puede quedar vacío o con preferencias; el planner los optimizará.

**Si elige "manual"** → preguntar:
```
Para cada formato que quieras publicar:
  • Frecuencia/semana (ej. reels: 3, stories: 7, carousels: 2)
  • Horario preferido (ej. reels: 19:00, stories: 08:30)
```

**6.3 Objetivo primario por red**:
```
¿Qué métrica persigues en {PLATAFORMA}?
  reach | engagement | conversion | retention | service
```

> **Nota**: en v2.0 la **cadencia emerge de la estrategia**, no se asume. Un cliente de
> awareness con budget alto puede publicar 2x/día. Un cliente de retención B2B puede
> publicar 1x/semana. El planner lo calcula, no es dogma.

### Fase 7 — ICP (sección `icp`)

**Reglas según `business_model`**:
- `b2c` → **omitir esta fase**. El `buyer_persona` ya cubre el consumidor final.
- `b2b` → **obligatoria**. Capturar la EMPRESA ideal:
  - Sector objetivo
  - Geografía de prospectos
  - Tamaño de empresa (solo/small/medium/large/mixed)
  - Decisor de compra (cargo)
  - Pain points de la EMPRESA (vs buyer_persona que son del humano)
  - Buying triggers (eventos que gatillan compra)
- `both` → **recomendada**. Capturar ICP para el lado B2B del negocio.

### Fase 8 — Mercado y competencia (sección `market`)

- 2-3 competidores principales (nombre + URL + redes si se tiene)
- Materias primas / commodities relevantes

### Fase 9 — Equipo comercial (sección `sales`)

- Nombre del vendedor que firmará outreach
- Cargo
- Canales de contacto preferidos
- SLA de respuesta esperado (horas)

### Fase 10 — Catálogo visual (sección `catalog`) — Opcional

Como en v1.0. Puede diferirse a `/brand-kit new`.

### Fase 11 — Credenciales (sección `credentials_status`)

Para cada plataforma activa + Ads si incluye pauta:
- Meta (IG + FB)
- TikTok
- Telegram
- Meta Ads (si budget.paid_media_monthly > 0)
- TikTok Ads (si aplica)

Estado: `has` / `needs` / `not_applicable`

### Fase 12 — Confirmación

Mostrar resumen completo estructurado y pedir confirmación.

### Fase 13 — Generar archivos

**Archivo 1**: `.claude/client-brief.json` según schema v2.0

**Archivo 2**: `.claude/state/kpi-tracking.json` inicializado:
```json
{
  "version": "1.0",
  "updated_at": "{ISO}",
  "period_start": "{ISO date}",
  "kpis": [
    {
      "metric": "{del brief}",
      "baseline": N,
      "target": M,
      "deadline": "...",
      "priority": "...",
      "current_value": N,
      "progress_pct": 0,
      "trajectory": "on_track",
      "measurements": [{"date": "{hoy}", "value": N, "source": "baseline"}]
    }
  ]
}
```

**Archivo 3**: `.env.example` con variables según plataformas Y según si incluye paid media.

### Fase 14 — Siguiente paso recomendado

```
✅ Brief creado. Resumen:
  📄 .claude/client-brief.json (v2.0)
  📄 .claude/state/kpi-tracking.json (inicializado)
  📄 .env.example

Siguientes pasos recomendados (en orden):
  1. Copia .env.example a .env y completa credenciales
  2. /setup-check — validar conexiones
  3. /audit — auditoría de cuentas actuales (Phase 1 del flujo de agencia)
  4. /brand-kit new — extraer identidad visual (Phase 2)
  5. /content-calendar — generar parrilla del próximo mes (Phase 3)

¿Quieres ejecutar /audit ahora para tener baseline real de las cuentas? (sí/no)
```

---

## Acción: `update [sección]`

Permite actualizar secciones específicas sin regenerar todo.

### Sin argumento

```
¿Qué sección quieres actualizar?

  Fundamentos:
    1. company — nombre, sector, producto, tono, plataformas
    2. catalog — productos y fotos de referencia
    3. credentials_status — estado de credenciales

  Estrategia (Phase 1):
    4. objectives — objetivos de negocio
    5. kpis — métricas medibles
    6. budget — presupuesto mensual
    7. buyer_persona — humano decisor
    8. network_roles — rol de cada red
    9. icp — perfil de empresa (B2B)

  Operación:
    10. market — competidores y commodities
    11. sales — vendedor y canales
```

### Con sección específica

Ej. `/briefing update kpis`:
1. Cargar brief con `_core/load-brief`
2. Mostrar KPIs actuales
3. Preguntar: añadir / editar / eliminar
4. Validar contra schema
5. Actualizar `updated_at`
6. Si se actualizan KPIs → también actualizar `.claude/state/kpi-tracking.json`

---

## Acción: `show`

Cargar vía `_core/load-brief` y mostrar formateado:

```
📋 BRIEF ACTIVO — {brand_name} (v2.0)

🏢 EMPRESA
  Sector: {industry}
  Producto: {product}
  Ubicación: {location}
  Tono: {tone}
  Plataformas: {platforms}

🎯 OBJETIVOS
  Primario: {objectives.primary}
  Horizonte: {objectives.timeline_days} días
  Narrativa: {objectives.narrative}

📊 KPIs (ver /dashboard para progreso)
  {for each kpi}
  • {metric}: {baseline} → {target} para {deadline} [{priority}]

💰 PRESUPUESTO MENSUAL ({budget.currency})
  Pauta: {paid_media_monthly}
  Producción: {production_monthly}
  Influencers: {influencer_monthly}
  Herramientas: {tools_monthly}

👤 BUYER PERSONA
  {buyer_persona.name} ({age_range}) — {role}
  Dolores: {pain_points}
  Formatos preferidos: {format_preferences}

📱 REDES
  {for each platform}
  • {platform}: {network_roles[platform].role_description}
    Frecuencia: {frequency_per_week}
    Objetivo: {primary_objective}

🏢 ICP (B2B)
  {if B2B: industry_target, geography, decision_maker_role}

📊 MERCADO
  Competidores: {market.competitors}
  Commodities: {market.commodities}

👤 EQUIPO COMERCIAL
  {sales.sender_name} — {sales.sender_role}
  SLA: {sales.response_sla_hours}h

🔑 CREDENCIALES
  {credentials_status details}

📅 Última actualización: {updated_at}
```

Al final, invocar `validate` implícito y mostrar warnings.

---

## Acción: `validate`

Verifica que el brief tenga todo lo necesario para operar. Chequea:

1. Campos obligatorios del schema v2.0
2. Al menos 1 KPI `priority: primary`
3. Si hay plataforma activa → debe tener `network_roles` para esa plataforma
4. Si `budget.paid_media_monthly > 0` → debe tener `credentials_status.meta_ads == "has"` (o al menos "needs")
5. `buyer_persona.format_preferences` coherente con `company.platforms`

Reporta ok ✅ o lista detallada de qué falta.

---

## Migración de brief v1.0 → v2.0

Si existe `.claude/client-brief.json` con `version: "1.0"`:

```
Detecté un brief v1.0. Necesita migración a v2.0 para usar los nuevos agentes
de agencia (account-auditor, performance-analyst, paid-media, producer).

Qué agrega v2.0:
  • objectives — objetivos de negocio
  • kpis — métricas medibles
  • budget — presupuesto
  • buyer_persona — humano decisor
  • network_roles — rol de cada red

¿Migramos ahora? (recomendado)
  s → Flujo rápido de 5 min con solo las secciones nuevas
  n → Mantener v1.0 (algunos agentes no funcionarán)
```

Si acepta, saltar las secciones ya rellenas de v1.0 y pedir solo las nuevas.

---

## Notas

- Este command **reemplaza al antiguo `/init`** (evita colisión con `/init` nativo).
- `/briefing` orquesta la creación pero puede invocar `brand-guardian` para catálogo visual o `account-auditor` después.
- La capa de 6 fases del flujo de agencia se refleja en qué commands se sugieren después:
  - Phase 1 → `/briefing` + `/audit`
  - Phase 2 → `/brand-kit new` + `/optimize-profiles`
  - Phase 3 → `/content-calendar`
  - Phase 4 → `/production-plan`
  - Phase 5 → `/publish-today` + `/community` + `/ads`
  - Phase 6 → `/report-monthly` + `/dashboard`
