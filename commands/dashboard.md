---
description: Dashboard ejecutivo del cliente — consolida KPIs, actividad reciente, pipeline, pauta, alertas activas y acciones recomendadas en una sola vista. Útil antes de reunión con cliente.
argument-hint: [--period 7d|30d|90d] [--save]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /dashboard

**Propósito**: Vista ejecutiva consolidada del estado completo del cliente. En un solo output ves: progreso de KPIs, actividad reciente de todas las fases, pipeline comercial, pauta, alertas activas y recomendaciones.

**Agente invocado**: `conductor` (modo `dashboard`)

**Fase del flujo de agencia**: **Vista cross-fase**

---

## Cuándo ejecutar

- **Antes de reunión con cliente** (semanal o mensual)
- **Monday morning check** — ver estado del cliente en 2 min
- **Después de un periodo largo sin usar el toolkit** — ponerte al día
- **Automático cada lunes** (opcional cron) — enviar dashboard por Telegram

---

## Qué incluye el dashboard

```
🚦 Estado operativo (locks, credenciales, agentes activos)
🎯 Progreso de KPIs (vs targets del brief)
📊 Actividad últimos 7d (posts, engagement, nuevos seguidores)
💬 Comunidad (pendientes, SLA)
💰 Pauta (gastado vs budget, campañas activas, CPA)
🎬 Producción (próxima sesión, piezas pendientes)
📊 Pipeline comercial (hot/warm leads)
⚠️ Alertas activas (eventos severity=high no consumidos)
➡️ Acciones recomendadas priorizadas
```

---

## Precondiciones

1. `_core/load-brief` → abortar si no hay brief
2. Opcional: `_core/preflight-check --domains telegram` (si `--save` enviará a Telegram)

---

## Flujo

### Paso 1 — Interpretar argumentos

- `--period` = ventana a analizar (`7d` default / `30d` / `90d`)
- `--save` = enviar dashboard a Telegram y guardar en `.claude/state/dashboards/`

### Paso 2 — Delegar al conductor

```
Task(
  subagent_type: "conductor",
  description: "Executive dashboard",
  prompt: """
    Modo: dashboard
    Period: {period}
    Save & send: {bool}

    Compila el dashboard ejecutivo del cliente leyendo:
    - .claude/state/posts/ (últimos {period})
    - .claude/state/reports/ (último)
    - .claude/state/kpi-tracking.json
    - .claude/state/ads/active-campaigns.json
    - .claude/state/leads/
    - .claude/state/performance/
    - .claude/state/locks/ (circuit breakers)
    - .claude/state/handoffs/ (eventos no consumidos severity=high)

    Produce el documento según el pipeline definido en tu modo dashboard.
    {Si --save: guardar en .claude/state/dashboards/{YYYY-MM-DD}.md Y enviar por Telegram}
  """
)
```

### Paso 3 — Presentar al usuario

Mostrar el dashboard completo en consola (el agente ya lo generó estructurado):

```
📊 DASHBOARD — {brand.name} — {FECHA}
Periodo analizado: {period}

🚦 ESTADO
  Posting: {OK/PAUSED}
  Promocional: {OK/PAUSED}
  Prospecting: {OK/PAUSED}
  Credenciales Meta: expira en {X}d
  Credenciales TikTok: {status}

🎯 KPIs ({overall_health})
┌──────────────────────────────┬─────┬─────┬──────┬──────────────┐
│ Métrica                      │ Base│ Act │ Tar  │ Trayectoria  │
├──────────────────────────────┼─────┼─────┼──────┼──────────────┤
│ leads_per_month_ig           │ 20  │ 42  │ 60   │ 🟢 on_track  │
│ reach_weekly_fb              │1500 │1200 │ 3000 │ 🔴 behind    │
└──────────────────────────────┴─────┴─────┴──────┴──────────────┘

📊 ACTIVIDAD ÚLTIMOS {period}
  Posts publicados: {N}
  Engagement total: {X}
  Nuevos seguidores: {+Y} (IG: {a}, FB: {b}, TikTok: {c})
  Mejor post: {detalle}

💬 COMUNIDAD
  Pendientes: {N} comentarios + {M} DMs
  SLA actual: {hours}h (target {brief.sales.response_sla_hours}h)
  Crisis activas: {count}

💰 PAUTA
  Gastado mes actual: ${spent} / ${budget} ({pct}%)
  Campañas activas: {N}
  CPA promedio: ${cpa}
  Mejor campaña: {name} (CPA ${X})

🎬 PRODUCCIÓN
  Próxima sesión agendada: {date}
  Piezas pendientes de rodaje: {count}

📊 PIPELINE COMERCIAL
  🔥 Hot leads activos: {N}
  ✅ Warm leads: {M}
  ⏳ En follow-up: {K}

⚠️ ALERTAS ACTIVAS ({N})
  {lista de eventos severity=high no consumidos}

➡️ ACCIONES RECOMENDADAS (priorizadas)
  1. {acción crítica}
  2. {acción importante}
  3. {acción con quick win}

{Si --save: 📄 Guardado en .claude/state/dashboards/{YYYY-MM-DD}.md}
{Si --save: 📧 Enviado por Telegram}
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `--period` | enum | `7d` | `7d` / `30d` / `90d` |
| `--save` | flag | false | Guardar en archivo + enviar por Telegram |

---

## Ejemplos de uso

```
/dashboard                  # vista rápida últimos 7 días
/dashboard --period 30d     # último mes completo
/dashboard --period 90d --save  # trimestre + guardar + Telegram
```

---

## Diferencia con /report-monthly

| Dimension | `/dashboard` | `/report-monthly` |
|---|---|---|
| Alcance | Vista instantánea del estado | Análisis profundo del mes anterior |
| Frecuencia | On-demand / semanal | Mensual (día 1) |
| Narrativa | Dashboard escaneable | Reporte ejecutivo narrativo |
| Audiencia | Interno (tú o manager) | Cliente (comparte directo) |
| Feedback loop | No emite insights | Emite `performance_insight` al planner |

---

## Notas

- El dashboard NO modifica nada, solo lee estado.
- Si una sección no tiene datos (ej. sin pauta configurada), se oculta en lugar de mostrar "0".
- Toda la lógica interna está en `agents/conductor.md` modo dashboard.
