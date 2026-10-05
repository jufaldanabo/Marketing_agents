---
name: load-brief
description: Carga y valida el client-brief.json del cliente activo. Devuelve el objeto parseado para inyectar como contexto a cualquier agente. Falla rápido si el brief no existe o es inválido.
allowed-tools: [Read, Bash]
model: claude-haiku-4-5
---

# Skill: load-brief

**Propósito**: Punto único de carga del `client-brief.json`. Todo agente que necesite contexto del cliente llama a este skill primero. Garantiza que el toolkit sea multi-tenant sin modificar nada por cliente.

**Schema**: `skills/_core/schemas/client-brief.schema.json`

---

## Cuándo invocar

- Al inicio de cualquier agente que personalice contenido o decisiones por cliente
- Al inicio de cualquier command que vaya a invocar un agente
- Antes de ejecutar operaciones que requieren identidad del cliente (publicación, prospección, etc.)

## Cuándo NO invocar

- Para comandos de setup inicial (`/briefing new` crea el archivo, no lo lee)
- Para operaciones de infraestructura puras (`/setup-railway`, `/security-audit`)

---

## Flujo

### Paso 1 — Localizar el archivo

Ruta esperada: `.claude/client-brief.json` relativa al cwd del usuario.

```bash
BRIEF_PATH=".claude/client-brief.json"

if [ ! -f "$BRIEF_PATH" ]; then
  echo "ERROR: No se encontró $BRIEF_PATH"
  echo "SUGERENCIA: Ejecuta /briefing new para crear el brief del cliente."
  exit 1
fi
```

### Paso 2 — Leer y parsear

Usa la tool `Read` para cargar el contenido completo. Parsea como JSON mentalmente — si hay error de parsing, aborta con mensaje claro:

```
ERROR: client-brief.json está malformado (JSON inválido en línea X).
SUGERENCIA: Ejecuta /briefing validate para diagnosticar.
```

### Paso 3 — Validar campos obligatorios (schema v2.0)

Verifica que estos campos existan y no estén vacíos:

| Path | Obligatorio | Nota |
|---|---|---|
| `version` | sí | debe ser `"2.0"` (o migrar si es `"1.0"`) |
| `created_at` | sí | ISO 8601 |
| `company.name` | sí | no vacío |
| `company.industry` | sí | no vacío |
| `company.product` | sí | no vacío |
| `company.tone` | sí | no vacío |
| `company.location` | sí | no vacío |
| `company.platforms` | sí | array ≥1 |
| `objectives.primary` | sí | enum válido |
| `objectives.timeline_days` | sí | integer 7-365 |
| `sales.sender_name` | sí | no vacío |
| `sales.sender_role` | sí | no vacío |

**Si el brief es v1.0**:
- No fallar; devolver warning con `migration_needed: true`
- Sugerir `/briefing update` para completar v2.0

**Campos opcionales pero importantes** (si faltan → warning, no error):
- `kpis` (array vacío = sin tracking de métricas)
- `budget` (sin budget → paid-media no puede operar)
- `buyer_persona` (sin persona → content-planner usa defaults)
- `network_roles` (sin roles → content-planner usa heurísticas por defecto)
- `icp` (solo requerido si es B2B)

**Si falta algo obligatorio**: Reporta exactamente qué falta y sugiere `/briefing update {sección}`.

### Paso 4 — Validar coherencia

- Si `company.platforms` incluye `"tiktok"` pero `credentials_status.tiktok` es `"not_applicable"` → warning (no bloqueante).
- Si `credentials_status.anthropic` no es `"has"` → warning crítico (bloqueante salvo en modo demo).

### Paso 5 — Devolver contexto estructurado (v2.0)

Al agente invocador, devuelve el objeto completo del brief más un bloque de "contexto resumido" que puede inyectar al system prompt:

```
📋 CONTEXTO DEL CLIENTE ACTIVO (brief v2.0)

Empresa: {company.name} ({company.industry}, {company.location})
Producto: {company.product}
Tono: {company.tone}
Plataformas activas: {company.platforms.join(", ")}

🎯 Objetivo primario: {objectives.primary} ({objectives.timeline_days}d)
   Narrativa: {objectives.narrative}

📊 KPIs ({kpis.length}):
{for each kpi: - {metric}: {baseline} → {target} [{priority}]}

💰 Presupuesto mensual: {budget.currency} {budget.paid_media_monthly or 0} pauta, {budget.production_monthly or 0} producción

👤 Buyer persona: {buyer_persona.name or "no definido"} ({buyer_persona.age_range})
   Dolores: {buyer_persona.pain_points.join("; ") or "no definidos"}
   Formatos: {buyer_persona.format_preferences.join(", ")}

📱 Roles de redes:
{for each platform in company.platforms:}
   • {platform}: {network_roles[platform].role_description or "no definido"} → {primary_objective}

{if icp} Cliente ideal (B2B):
   Sector: {icp.industry_target}
   Geografía: {icp.geography}
   Decisor: {icp.decision_maker_role or "no definido"}

Vendedor: {sales.sender_name} ({sales.sender_role})

{if market.competitors} Competidores: {market.competitors.map(c => c.name).join(", ")}
{if market.commodities} Commodities: {market.commodities.join(", ")}
```

Cada agente usa las secciones relevantes a su dominio:
- `content-planner` → objectives, kpis, buyer_persona, network_roles
- `paid-media` → objectives, budget, kpis, buyer_persona
- `performance-analyst` → objectives, kpis (medir vs targets)
- `account-auditor` → objectives, kpis (para calcular baselines reales)

---

## Output

Al agente invocador, devuelve:

```json
{
  "ok": true,
  "brief": { /* objeto completo del brief */ },
  "context_summary": "📋 CONTEXTO DEL CLIENTE ACTIVO...",
  "warnings": [
    "credentials_status.tiktok = needs — publicaciones TikTok no funcionarán"
  ]
}
```

En caso de error:

```json
{
  "ok": false,
  "error": "missing_required_field",
  "detail": "company.industry no está definido",
  "suggestion": "Ejecuta /briefing update company.industry"
}
```

---

## Notas

- Este skill es **síncrono y rápido** (modelo haiku, lectura de JSON local).
- No hace llamadas de red ni modifica archivos.
- Si el agente invocador va a modificar el brief, debe usar `/briefing update` (no editar el JSON directamente).
- El `context_summary` está diseñado para pegarse directamente en system prompts sin más procesamiento.
