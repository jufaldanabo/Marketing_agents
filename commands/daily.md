---
description: Ejecuta el flujo completo diario del cliente — procesa eventos pendientes + publica si toca + comunidad + reporte si es noche + semanal si es lunes + mensual si es día 1. Entry point del día.
argument-hint: [--dry-run] [--only {publisher|monitor|community|...}]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /daily

**Propósito**: Ejecutar el flujo completo diario del cliente en un solo command. Esto reemplaza correr `/publish-today`, `/community`, `/social-report`, etc. manualmente — el `conductor` decide qué correr según hora, día del mes y estado del sistema.

**Agente invocado**: `conductor` (modo `daily`)

**Fase del flujo de agencia**: **Orquestación cross-fase**

---

## Cuándo ejecutar

- **Automático**: Railway cron 9:00 AM (configurable). Un solo cron corre `/daily` en lugar de 10 crons separados.
- **Manual**: cuando quieres ejecutar el ciclo diario on-demand sin esperar al cron.
- **Dry-run**: antes de activar automatización en producción para verificar qué correría.

---

## Qué hace el conductor en modo daily

```
1. Procesar eventos pendientes (crisis, KPIs, etc. — SE HACE PRIMERO)
2. Check circuit breakers (posting.lock, promotional.lock)
3. Si no hay parrilla del mes → spawn content-planner (urgente)
4. Si hoy toca publicar → spawn content-publisher
5. Si cada 4h → spawn community-manager
6. Si noche (≥21h) → spawn social-monitor
7. Si es lunes → spawn market-analyst + performance-analyst (weekly)
8. Si es día 1 → spawn performance-analyst (monthly report)
9. Si es día 20 → spawn producer (para próximo mes)
10. Si es día 25 → spawn content-planner (próximo mes)
11. Resumen por Telegram
```

Ver `agents/conductor.md` para la lógica completa.

---

## Precondiciones

1. `_core/load-brief` → abortar si no hay brief
2. `_core/preflight-check --domains anthropic,meta,telegram` → abortar si críticos

---

## Flujo

### Paso 1 — Interpretar argumentos

- `--dry-run` = reporta qué correría pero no spawnea agentes
- `--only {agent-name}` = fuerza solo ese agente (ignora lógica de día/hora)

### Paso 2 — Delegar al conductor

```
Task(
  subagent_type: "conductor",
  description: "Daily marketing flow",
  prompt: """
    Modo: daily
    Dry run: {bool}
    Force only: {agent-name or null}
    Date/time context: {current_datetime}

    Ejecuta el flujo daily completo según el pipeline definido en tu system prompt.
    Reporta cada paso: cuáles se ejecutaron, cuáles se saltaron (con razón), y
    cuáles alertas se enviaron.
  """
)
```

### Paso 3 — Presentar resultado

```
🚀 DAILY FLOW COMPLETADO — {brand.name} — {FECHA} {HORA}

🚦 ESTADO INICIAL
  Posting: {OK/PAUSED}
  Promocional: {OK/PAUSED}
  Eventos pendientes atendidos: {N}

🤖 AGENTES EJECUTADOS
  ✅ content-publisher — publicó {post_url}
  ✅ community-manager — procesó {X} items
  ⏭️ social-monitor — skip (aún no es noche)
  ⏭️ market-analyst — skip (no es lunes)
  ...

⚠️ ALERTAS GENERADAS
  {lista si hubo}

➡️ SIGUIENTES EJECUCIONES ESPERADAS
  Próximo /daily automático: {next_cron_time}
  Próximo /report-monthly: día 1 del próximo mes
```

---

## Argumentos

| Arg | Tipo | Descripción |
|---|---|---|
| `--dry-run` | flag | Simula sin ejecutar |
| `--only` | string | Fuerza solo un agente específico |

---

## Ejemplos de uso

```
/daily                              # ejecución completa normal
/daily --dry-run                    # ver qué correría sin hacerlo
/daily --only content-publisher     # forzar solo publicador
```

---

## Automatización recomendada en Railway

Un solo cron reemplaza múltiples:
```
# Antes (10 crons separados):
0 9 * * *   claude /publish-today
0 */4 * * * claude /community
0 22 * * *  claude /social-report
0 9 * * 1   claude /market-intel
...

# Ahora (1 cron):
0 * * * *   claude /daily
```

El conductor sabe qué correr en cada hora/día. Más robusto, menos duplicación.

---

## Notas

- Si no hay brief, aborta con mensaje claro.
- Si todos los agentes están paused por locks, reporta "no hay nada que ejecutar" y termina.
- Toda la lógica de qué correr está en `agents/conductor.md` — este command solo delega.
- Para forzar solo un agente, prefiero `/publish-today` o `/community` directo (más claros que `--only`).
