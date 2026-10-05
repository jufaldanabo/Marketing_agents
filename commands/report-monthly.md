---
description: Genera el informe mensual del cliente — KPIs vs targets, top/peores posts, análisis de pauta, aprendizajes del mes y recomendaciones para el próximo. Phase 6 del flujo de agencia.
argument-hint: [YYYY-MM]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /report-monthly

**Propósito**: El reporte mensual es el **artefacto más importante del ciclo de agencia** — mide el progreso real contra los KPIs del brief, extrae aprendizajes y alimenta la planificación del próximo mes.

**Agente invocado**: `performance-analyst` (vía Task tool, modo `monthly`)

**Fase del flujo de agencia**: **6 — Monitoreo y optimización**

---

## Cuándo ejecutar

- **Día 1 de cada mes** (automático con Railway cron) — reporta el mes anterior
- Antes de reunión mensual con el cliente
- Después de un cambio importante de estrategia (para medir impacto)
- `/report-monthly 2026-03` para reporte histórico específico

---

## Precondiciones

1. `_core/load-brief` → necesita `brief.kpis`, `brief.objectives`
2. Verificar que exista `.claude/state/kpi-tracking.json`
   - Si no existe → crear con baselines del brief
3. `_core/preflight-check --domains meta,telegram`

---

## Flujo

### Paso 1 — Interpretar argumentos

- `$1` = target period en formato `YYYY-MM` (default = mes anterior)

Validar que el período tenga datos (al menos un `post_published` event en ese rango).

### Paso 2 — Delegar al agente en modo mensual

```
Task(
  subagent_type: "performance-analyst",
  description: "Generate monthly performance report",
  prompt: """
    Período: {target_period}

    Pipeline esperado:
    1. Agregar métricas de posts publicados en el período
    2. Fetch métricas finales via Meta Graph API
    3. Calcular progreso de cada KPI del brief vs tiempo transcurrido
    4. Actualizar .claude/state/kpi-tracking.json con measurements
    5. Analizar por formato / pilar / horario / plataforma
    6. Si hay pauta activa: compilar performance de campañas
    7. Extraer aprendizajes concretos (datos, no narrativa)
    8. Generar recomendaciones para próximo mes
    9. Guardar en .claude/state/performance/monthly/{YYYY-MM}.md
    10. Emitir performance_insight event al content-planner
    11. Si hay KPIs behind target, emitir kpi_behind_target al conductor
    12. Enviar resumen ejecutivo por Telegram

    Devuelve: path del reporte + overall_health color + top 3 insights.
  """
)
```

### Paso 3 — Presentar resultado al usuario

```
📊 REPORTE MENSUAL — {brand.name} — {MONTH} {YEAR}

🏥 OVERALL HEALTH: {🟢 verde | 🟡 amarillo | 🔴 rojo}

🎯 PROGRESO DE KPIs
  {for each kpi primary:}
  - {metric}: {current} / {target} ({pct}%) — {trajectory}

📈 TOP INSIGHTS
  1. {insight}
  2. {insight}
  3. {insight}

🚀 RECOMENDACIONES PARA PRÓXIMO MES
  Para content-planner: {sugerencias emitidas vía evento}
  Para paid-media: {sugerencias si aplica}
  Para community-manager: {sugerencias si aplica}

⚠️ ALERTAS
  {if any KPI primary behind: alerta para el humano}

📄 Reporte completo: .claude/state/performance/monthly/{YYYY-MM}.md
📧 Enviado por Telegram también.

➡️ SIGUIENTES PASOS
  1. Reunión con cliente para revisar reporte
  2. /content-calendar — generar parrilla del próximo mes (incorpora insights automáticamente)
  3. /ads optimize — ajustar campañas si performance-analyst lo recomendó
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | YYYY-MM | mes anterior | Período a reportar |

---

## Ejemplos de uso

```
/report-monthly                 # mes anterior
/report-monthly 2026-03         # marzo específico
```

---

## El valor del feedback loop

Este command es el **cierre del ciclo**. Al terminar:

1. **`content-planner`** recibe `performance_insight` → próxima parrilla incorpora qué funcionó
2. **`paid-media`** recibe sugerencias de optimización
3. **`conductor`** recibe alertas si KPIs están behind
4. **El humano** recibe reporte ejecutivo para reunión con cliente

Sin este reporte, el toolkit opera sin aprendizaje — publica mensualmente pero no mejora.

---

## Notas

- Si el período no tiene suficientes datos (ej. mes incompleto), el agente lo señala y produce reporte parcial.
- El reporte está diseñado para ser compartido con el cliente directamente (es ejecutivo, no técnico).
- Toda la lógica interna está en `agents/performance-analyst.md`.
- Para análisis 24h/72h de un post específico individual, el `performance-analyst` corre automáticamente vía Railway cron (no requiere command).
