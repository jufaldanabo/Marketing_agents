---
description: Genera plan de producción mensual batch (shot lists, scripts, call sheets, specs de edición) para que el cliente grabe todo el contenido del mes en 1-2 días. Phase 4 del flujo de agencia.
argument-hint: [YYYY-MM] [--include-ads]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /production-plan

**Propósito**: Convertir la parrilla aprobada del próximo mes en un plan de producción ejecutable: sesiones agrupadas, shot lists, call sheets, specs de edición y estimación de costos vs presupuesto.

**Agente invocado**: `producer` (vía Task tool)

**Fase del flujo de agencia**: **4 — Producción**

---

## Cuándo ejecutar

- **Día 20 de cada mes** (automático con Railway cron) — para que el cliente pueda agendar rodaje del próximo mes
- Después de `/content-calendar` aprobada (si quiere planear producción inmediatamente)
- On-demand cuando `paid-media` necesita creativos adicionales fuera de la parrilla orgánica

---

## Precondiciones

1. `_core/load-brief` → necesita `brief.budget.production_monthly`
2. `_core/load-brand-kit` → necesita `visual_identity` para dictar estilo del rodaje
3. Verificar que exista `.claude/state/calendar/{target_month}.json` con `status: "approved"`
   - Si no → abortar y sugerir `/content-calendar` primero

---

## Flujo

### Paso 1 — Interpretar argumentos

- `$1` = target month en formato `YYYY-MM` (default: próximo mes)
- `--include-ads` = incluir también producción para creativos de pauta

### Paso 2 — Verificar parrilla aprobada

Leer `.claude/state/calendar/{target_month}.json`. Validar:
- Existe
- `status == "approved"`
- `items.length > 0`

Si falta algo, abortar con mensaje claro.

### Paso 3 — Delegar al agente

```
Task(
  subagent_type: "producer",
  description: "Generate production plan for approved calendar",
  prompt: """
    Genera plan de producción batch para el mes {target_month}.

    Precondiciones ya validadas:
    - Parrilla aprobada en .claude/state/calendar/{target_month}.json
    - Budget producción mensual: ${brief.budget.production_monthly}

    Pipeline esperado:
    1. Clasificar las {N} piezas por tipo de producción
    2. Agrupar en sesiones óptimas
    3. Generar shot lists ejecutables por sesión
    4. Enriquecer guiones de reels/videos
    5. Call sheets por día
    6. Specs de edición
    7. Estimar costos vs budget
    8. Si excede budget, proponer ajustes al planner
    9. Pasar por telegram-approval
    10. Si aprobado, emitir production_plan_ready al conductor

    include_ads_creatives: {true/false}

    Reporta rutas de archivos generados + resumen ejecutivo.
  """
)
```

### Paso 4 — Presentar resultado

```
🎬 PLAN DE PRODUCCIÓN LISTO — {brand.name} {target_month}

📄 Dossier completo: .claude/state/production/{target_month}/dossier.md

📅 RESUMEN
  Piezas a producir: {N}
  Sesiones recomendadas: {M}
  Días de rodaje: {D}
  Costo estimado: ${total} {currency}
  Budget disponible: ${brief.budget.production_monthly}
  {✅ Dentro de presupuesto | ⚠️ Excede en $X}

📋 SESIONES
  {for each session: - Sesión {id}: {type} ({duration}h) - {location}}

📘 ARCHIVOS GENERADOS
  - dossier.md (documento completo)
  - sessions.json (sesiones estructuradas)
  - shot-lists/ (shot list por sesión)
  - call-sheets/ (call sheet por día)
  - edit-specs.md (specs de post-producción)
  - cost-estimate.json (estimación detallada)

➡️ SIGUIENTES PASOS
  1. Revisar el dossier y agendar días de rodaje
  2. Compartir shot-lists con fotógrafo/crew
  3. Al terminar producción: /publish-today empezará a usar las piezas en {target_month}
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | YYYY-MM | próximo mes | Mes objetivo |
| `--include-ads` | flag | false | Incluir creativos de pauta |

---

## Ejemplos de uso

```
/production-plan                        # próximo mes
/production-plan 2026-05                # mes específico
/production-plan 2026-05 --include-ads  # con creativos de pauta
```

---

## Notas

- Si la parrilla no está aprobada, este command NO puede operar.
- El agente puede emitir `production_constraint` si piezas no son viables con el budget — en ese caso el conductor escala al humano.
- Los call sheets y shot lists están diseñados para que **un fotógrafo externo pueda ejecutar sin presencia del toolkit**.
- Toda la lógica interna está en `agents/producer.md`.
