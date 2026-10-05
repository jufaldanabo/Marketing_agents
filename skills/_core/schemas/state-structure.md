# State Structure — Contract between agents

Todo agente del toolkit lee y escribe en `.claude/state/` siguiendo esta estructura.
Esto es el **contrato de interoperabilidad** entre agentes.

**Regla de oro**: Un agente NUNCA escribe en el directorio de otro. Los handoffs se hacen
copiando a `handoffs/` o leyendo del output del agente productor.

---

## Jerarquía completa

```
.claude/
├── client-brief.json              ← fuente de verdad del cliente (schema: client-brief.schema.json)
├── brand-kit.json                 ← identidad visual (schema: brand-kit.schema.json)
├── brand-images/
│   └── products/
│       ├── product-catalog.json
│       └── {product-slug}/
│           ├── product-info.json
│           └── ref-{N}.{ext}
│
└── state/
    │
    ├── calendar/                  ← output: content-planner
    │   ├── {YYYY-MM}.json        ← parrilla mensual aprobada
    │   └── {YYYY-MM}.draft.json  ← en revisión
    │
    ├── posts/                     ← output: content-publisher
    │   └── {YYYY-MM-DD}.json     ← post publicado + metadatos API response
    │
    ├── drafts/                    ← handoff: publisher → approval-gatekeeper
    │   └── {draft-id}.json       ← contenido pendiente de aprobación
    │
    ├── approvals/                 ← estado: approval-gatekeeper
    │   ├── telegram-offset.json  ← último update_id procesado
    │   └── pending/
    │       └── {draft-id}.json   ← aprobación en curso
    │
    ├── reports/                   ← output: social-monitor
    │   └── {YYYY-MM-DD}.md       ← reporte nocturno
    │
    ├── intel/                     ← output: market-analyst
    │   └── {YYYY-MM-DD}.md       ← reporte de mercado
    │
    ├── leads/                     ← output: sales-prospector
    │   └── {YYYY-MM-DD}/
    │       ├── leads.json        ← pipeline completo
    │       ├── {lead-id}.md      ← ficha individual
    │       └── outreach/
    │           └── {lead-id}.json ← mensajes generados
    │
    ├── followups/                 ← estado: sales-prospector
    │   └── tracking.json         ← estado de secuencias de follow-up
    │
    ├── locks/                     ← circuit breakers e idempotency
    │   ├── posting.lock          ← si existe → pausa publisher
    │   ├── prospecting.lock      ← si existe → pausa prospector
    │   └── {operation-key}.lock  ← idempotency key por operación
    │
    ├── handoffs/                  ← comunicación explícita entre agentes
    │   └── {from-agent}-to-{to-agent}/
    │       └── {timestamp}.json  ← evento con payload tipado
    │
    └── logs/                      ← observabilidad
        └── {agent}/
            └── {YYYY-MM-DD}.jsonl ← structured logs, una línea por evento
```

---

## Convenciones de nombres de archivo

| Pattern | Uso | Ejemplo |
|---|---|---|
| `{YYYY-MM}.json` | Documento mensual | `2026-03.json` |
| `{YYYY-MM-DD}.json` | Documento diario | `2026-03-15.json` |
| `{YYYY-MM-DD}.md` | Reporte legible por humano | `2026-03-15.md` |
| `{slug}.json` | Documento por entidad | `tela-algodon.json` |
| `{draft-id}` | 8 chars de SHA1 | `a1b2c3d4` |
| `{lead-id}` | 8 chars de SHA1 | `e5f6g7h8` |

**Draft ID**: `sha1(timestamp + topic)[:8]`
**Lead ID**: `sha1(company_name + contact_name)[:8]`
**Operation key**: `sha1(agent + operation + target_date)[:16]`

---

## Schema de handoff event

Todos los archivos en `.claude/state/handoffs/{from}-to-{to}/` siguen este formato:

```json
{
  "event_id": "sha1(timestamp+from+to)[:12]",
  "schema_version": "1.0",
  "from_agent": "social-monitor",
  "to_agent": "conductor",
  "event_type": "crisis_detected",
  "severity": "high",
  "timestamp": "2026-03-15T22:14:00Z",
  "payload": {
    "...": "estructura específica según event_type"
  },
  "requires_action": true,
  "consumed_at": null,
  "consumed_by": null
}
```

**Consumo**: El agente destino marca `consumed_at` + `consumed_by` cuando procesa el evento.
No se borra el archivo (auditoría); se mueve a `handoffs/consumed/` solo si crece demasiado.

---

## Event types estándar (taxonomía completa v2.0)

Todos los eventos los **procesa `conductor`** salvo los que indican destino explícito distinto.

### SEVERITY: HIGH (procesar primero)

| Event type | From | To | Payload |
|---|---|---|---|
| `crisis_detected` | social-monitor, community-manager | conductor | `{platform, trigger, details, suggested_action}` |
| `kpi_behind_target` | performance-analyst | conductor | `{kpi, current_pct, expected_pct, deadline}` |
| `token_expiring` (<3d) | social-monitor | conductor | `{platform, days_remaining}` |
| `market_risk` | market-analyst | conductor | `{risk_type, detail, suggested_action}` |
| `production_constraint` | producer | content-planner | `{month, unachievable_pieces, suggestion}` |
| `posting_paused` | conductor | content-publisher | `{reason, duration}` |

### SEVERITY: MEDIUM

| Event type | From | To | Payload |
|---|---|---|---|
| `token_expiring` (3-10d) | social-monitor | conductor | `{platform, days_remaining}` |
| `market_opportunity` | market-analyst | content-planner (via conductor) | `{opportunity_type, detail, suggestion, urgency}` |
| `kpi_adjustment_needed` | account-auditor | conductor | `{kpi, current_target, suggested_target, reason}` |
| `campaign_underperforming` | performance-analyst | paid-media (via conductor) | `{campaign_slug, metrics, thresholds_violated}` |
| `lead_responded` (high intent) | sales-prospector | conductor | `{lead_id, company, intent, suggested_next_action}` |
| `approval_edit_requested` | approval-gatekeeper | originating-agent | `{draft_id, edit_instructions}` |

### SEVERITY: INFO (feedback loops / tracking)

| Event type | From | To | Payload |
|---|---|---|---|
| `audit_completed` | account-auditor | conductor | `{audit_date, report_path, kpi_adjustments_count}` |
| `calendar_approved` | content-planner | content-publisher | `{month, items_count, calendar_path}` |
| `production_plan_ready` | producer | conductor | `{month, dossier_path, sessions_count, cost}` |
| `post_published` | content-publisher | social-monitor, performance-analyst | `{post_id, platform, post_url, topic, pillar}` |
| `performance_insight` | performance-analyst | content-planner (via conductor) | `{period, winning_pillars, winning_formats, best_times, recommendations}` |
| `post_candidate_for_boost` | performance-analyst | paid-media (via conductor) | `{post_id, performance_vs_avg}` |
| `campaign_pending_launch` | paid-media | performance-analyst | `{campaign_slug, ready_at}` |
| `prospecting_cycle_completed` | sales-prospector | conductor | `{candidates, hot, warm, report_path}` |
| `approval_granted` | approval-gatekeeper | originating-agent | `{draft_id, approved_at}` |
| `approval_rejected` | approval-gatekeeper | originating-agent | `{draft_id, reason}` |
| `faq_updated` | community-manager | conductor | `{new_entries_count}` |

### Flujo de feedback loop completo

El **loop fundamental del sistema** es:

```
1. content-publisher publica → emite post_published
2. performance-analyst analiza 24h/72h → emite post_candidate_for_boost (si aplica)
3. performance-analyst mensual → emite performance_insight
4. conductor acumula insights en .claude/state/insights/pending-for-planner.json
5. content-planner (siguiente ciclo) lee los insights pendientes y ajusta la parrilla
6. Loop vuelve a 1
```

Este loop convierte el toolkit de "ejecutor mecánico" a "sistema que aprende".

---

## Schema de log line (JSONL)

Una línea por evento en `.claude/state/logs/{agent}/{YYYY-MM-DD}.jsonl`:

```json
{"ts":"2026-03-15T10:23:45Z","agent":"content-publisher","level":"info","event":"post_published","platform":"instagram","post_id":"17891...","duration_ms":2340}
```

**Niveles**: `debug`, `info`, `warn`, `error`
**Campos obligatorios**: `ts`, `agent`, `level`, `event`
**Campos sugeridos**: `duration_ms`, `error`, `operation_key`

---

## Reglas de concurrencia

1. **Un solo escritor por archivo**: solo el agente dueño de un directorio escribe en él.
2. **Lectores múltiples OK**: cualquier agente puede leer de cualquier directorio.
3. **Locks exclusivos**: para operaciones críticas, crear `locks/{operation-key}.lock` con PID + timestamp. Borrar al terminar.
4. **Lock stale**: si un lock tiene más de 1 hora, el nuevo agente puede sobrescribirlo (crash recovery).

---

## Idempotency

Operaciones destructivas (publicar, enviar mensaje) deben:

1. Calcular `operation_key = sha1(agent + action + target_date + content_hash)[:16]`
2. Verificar si existe `.claude/state/locks/{operation_key}.lock` → si sí, operación ya ejecutada
3. Crear el lock ANTES de la operación
4. Si la operación es exitosa, mover el lock a `.claude/state/locks/completed/`
5. Si falla, dejar el lock para que `/retry-failed` lo procese

---

## Retention

| Directorio | Retention | Nota |
|---|---|---|
| `calendar/` | Infinito | Histórico de parrillas |
| `posts/` | Infinito | Auditoría de publicaciones |
| `drafts/` | 30 días | Limpiar borradores no aprobados viejos |
| `handoffs/` | 90 días | Luego mover a `handoffs/archive/` |
| `logs/` | 30 días | Comprimir mensualmente |
| `locks/` | Hasta completar | O 24h si stale |
