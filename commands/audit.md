---
description: Audita el estado actual de las cuentas sociales del cliente (IG/FB/TikTok) y benchmarkea contra competidores. Phase 1 del flujo de agencia — produce baseline real de KPIs y recomendaciones iniciales.
argument-hint: [full | client-only | competitors-only] [--platforms ig,fb,tt]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /audit

**Propósito**: Diagnóstico profundo del estado actual del cliente en redes sociales. Es el **primer paso operativo** después de `/briefing new` — valida que los KPIs sean realistas y actualiza baselines con mediciones reales.

**Agente invocado**: `account-auditor` (vía Task tool)

**Fase del flujo de agencia**: **1 — Diagnóstico y estrategia**

---

## Cuándo ejecutar

- Al onboarding de un cliente nuevo (justo después de `/briefing new`)
- Trimestralmente para re-calibrar baselines
- Después de un cambio importante (rebranding, nuevo producto, cambio de estrategia)
- Antes de `/report-monthly` del primer mes (para tener punto de comparación)

---

## Precondiciones

1. Invocar skill `_core/load-brief` → abortar si no hay brief con mensaje "Ejecuta `/briefing new` primero"
2. Invocar skill `_core/load-brand-kit` → warning si no hay (puede operar sin él)
3. Invocar skill `_core/preflight-check --domains anthropic,meta` → abortar si Meta tokens no funcionan
4. Si `brief.company.platforms` incluye `tiktok` → también `--domains tiktok`

---

## Flujo

### Paso 1 — Interpretar argumentos

- `$1` = scope: `full | client-only | competitors-only` (default `full`)
- `--platforms` = subset de plataformas a auditar (default: todas en brief)

Si args no se proveen, confirmar con el usuario:
```
Voy a auditar:
  📱 Plataformas: {brief.company.platforms}
  🎯 Scope: {scope}
  🏢 Competidores: {brief.market.competitors.length} definidos

Tomará 3-7 minutos. ¿Procedo? (s/n)
```

### Paso 2 — Delegar al agente

```
Task(
  subagent_type: "account-auditor",
  description: "Audit current social accounts and competitors",
  prompt: """
    Audita el estado actual del cliente del brief activo.

    Scope: {scope}
    Platforms: {platforms}

    Flujo esperado:
    1. Fetch métricas via Meta Graph API para cada plataforma
    2. Scraping público de competidores
    3. Cross-análisis + validación de realismo de KPIs
    4. Reporte estructurado en .claude/state/audits/{YYYY-MM-DD}/report.md
    5. Actualizar baselines en .claude/state/kpi-tracking.json
    6. Emitir evento audit_completed al conductor
    7. Si hay KPIs unrealistic, emitir kpi_adjustment_needed

    Reporta el camino al reporte y los 3 hallazgos más importantes.
  """
)
```

### Paso 3 — Presentar resultado

```
✅ AUDITORÍA COMPLETADA — {brand.name}

📄 Reporte completo: .claude/state/audits/{YYYY-MM-DD}/report.md

🎯 BASELINE DE KPIs ACTUALIZADO
  {for each kpi del brief: - {metric}: medido {value} (baseline previo: {old_value})}

🚨 KPIs MARCADOS COMO IRREALES (ajuste sugerido)
  {if any: lista con targets sugeridos}

🔥 TOP 3 HALLAZGOS CRÍTICOS
  1. {hallazgo}
  2. {hallazgo}
  3. {hallazgo}

💡 QUICK WINS (próximos 7 días)
  {lista de recomendaciones inmediatas}

➡️ SIGUIENTES PASOS SUGERIDOS
  1. /briefing update kpis (si hay ajustes sugeridos)
  2. /optimize-profiles (si el reporte detectó bios/perfiles subóptimos)
  3. /brand-kit new (si coherencia visual <50%)
  4. /content-calendar (una vez que el baseline está sólido)
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | enum | `full` | `full` / `client-only` / `competitors-only` |
| `--platforms` | lista | todas | Filtrar plataformas (`ig,fb,tt`) |

---

## Ejemplo de uso

```
/audit
/audit full
/audit client-only --platforms ig,tt
/audit competitors-only
```

---

## Notas

- Este command NO modifica la bio/perfil del cliente (solo analiza). Para optimizar perfiles usar `/optimize-profiles` después.
- Los baselines actualizados aquí son leídos por `performance-analyst` para medir progreso.
- Si el agente detecta tokens de Meta por vencer, emite evento `token_expiring` al conductor.
- Toda la lógica interna está en `agents/account-auditor.md` — este command solo delega.
