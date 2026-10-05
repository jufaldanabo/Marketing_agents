---
description: Diseña, optimiza o reporta campañas de pauta en Meta Ads (IG+FB) y TikTok Ads. Phase 5 del flujo de agencia (pauta). Nunca gasta sin aprobación humana.
argument-hint: new | optimize | report [--platform meta|tiktok|both] [--campaign slug]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /ads

**Propósito**: Gestión de pauta digital — diseño de campañas, optimización de activas, reportes de performance.

**Agente invocado**: `paid-media` (vía Task tool)

**Fase del flujo de agencia**: **5 — Publicación, comunidad y pauta** (sub-fase pauta)

---

## Cuándo ejecutar

- **`new`**: Al inicio de un ciclo mensual de pauta o cuando `brief.budget.paid_media_monthly > 0`
- **`optimize`**: Cuando `performance-analyst` emitió `campaign_underperforming` evento
- **`report`**: Mensual (Railway cron día 1) o on-demand antes de reunión con cliente
- **Automático semanal** (lunes): modo `optimize` para campañas activas con >7 días

---

## Precondiciones

1. `_core/load-brief` → necesita `brief.objectives`, `brief.budget.paid_media_monthly`, `brief.kpis`, `brief.buyer_persona`
2. `_core/load-brand-kit` → para coherencia de creativos
3. `_core/preflight-check --domains anthropic,meta,meta_ads` + `tiktok_ads` si aplica

**CRÍTICO**: Si `brief.budget.paid_media_monthly == 0` o `credentials_status.meta_ads != "has"` → **abortar** con mensaje claro sobre qué configurar primero.

---

## Flujo

### Paso 1 — Interpretar argumentos

- `$1` = modo: `new | optimize | report` (si no se provee, preguntar)
- `--platform` = `meta | tiktok | both` (default: según brief + credenciales)
- `--campaign` = slug de campaña específica (si optimize/report)

### Paso 2 — Delegar al agente

```
Task(
  subagent_type: "paid-media",
  description: "Paid media campaign management",
  prompt: """
    Modo: {mode}
    Platform: {platform}
    Campaign: {campaign_slug or 'all'}

    Objetivo principal del brief: {brief.objectives.primary}
    KPIs activos: {kpis con priority primary}
    Budget mensual disponible: ${brief.budget.paid_media_monthly}

    Pipeline esperado para modo "{mode}":
    - new: diseñar campaña → audiencias → creativos A/B → aprobación → instrucciones step-by-step
    - optimize: analizar métricas vs criterios de pivote → proponer ajustes → aprobación → instrucciones
    - report: compilar performance de campañas activas → documento mensual

    NUNCA lanza campañas automáticamente — produce instrucciones ejecutables por el humano en Ads Manager.
    SIEMPRE pasa por telegram-approval antes de generar instrucciones de lanzamiento.
  """
)
```

### Paso 3 — Presentar resultado

**Si modo = `new`**:
```
📣 CAMPAÑA DISEÑADA — {campaign.name}

🎯 OBJETIVO: {campaign.objective}
💰 BUDGET: ${campaign.total_budget} ({campaign.daily_budget}/día)
👥 AUDIENCIAS: {campaign.audiences_count}
🎨 CREATIVOS: {creatives_count} variantes

📄 Documento completo: .claude/state/ads/campaigns/{slug}.md
📘 Instrucciones de lanzamiento: {slug}-launch-guide.md

⏭️ SIGUIENTE PASO
  Seguir las instrucciones en el launch-guide.md para lanzar manualmente en:
  - business.facebook.com (Meta Ads Manager)
  - ads.tiktok.com (si aplica)

  Al lanzar, actualiza el campaign_id en el archivo .md para que
  performance-analyst pueda monitorear.
```

**Si modo = `optimize`**:
```
🔧 AJUSTES RECOMENDADOS — {campaign.name}

Problemas detectados:
  {lista de métricas que gatillaron la optimización}

Cambios propuestos:
  1. {cambio concreto}
  2. {cambio concreto}

📘 Instrucciones de implementación: .claude/state/ads/campaigns/{slug}-optimization-{date}.md

Impacto esperado: ...
```

**Si modo = `report`**:
```
📊 REPORTE DE PAUTA — {MONTH} {YEAR}

Gastado: ${spent} / ${budget} presupuestado ({pct}%)
Resultados:
  - {X} leads / conversiones
  - CPL/CPA promedio: ${cost}
  - Mejor campaña: {name}
  - Peor campaña: {name}

📄 Reporte completo: .claude/state/ads/reports/{YYYY-MM}.md

Enviado por Telegram también.
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | enum | preguntar | `new` / `optimize` / `report` |
| `--platform` | enum | según brief | `meta` / `tiktok` / `both` |
| `--campaign` | string | — | Slug de campaña específica |

---

## Ejemplos de uso

```
/ads new                        # nueva campaña (flujo guiado)
/ads optimize --campaign leads-abril
/ads report                     # último mes
/ads new --platform tiktok      # solo TikTok Ads
```

---

## Notas

- **Nunca lanza ni gasta dinero automáticamente**. Produce instrucciones step-by-step.
- Requiere **pixel + CAPI instalados** en el sitio del cliente si el objetivo es conversiones. El agente lo valida y aborta si falta.
- `paid-media` coordina con `producer` si una campaña necesita creativos no existentes en la parrilla orgánica.
- `performance-analyst` monitorea las campañas activas registradas en `.claude/state/ads/active-campaigns.json`.
- Toda la lógica interna está en `agents/paid-media.md`.
