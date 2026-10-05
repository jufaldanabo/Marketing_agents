---
description: Genera informe de inteligencia de mercado (precios + competidores) delegando al agente market-analyst
argument-hint: "[prices|competitors|all] [--week-offset N]"
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /market-intel

**Propósito**: Monitorea precios de materias primas y actividad pública de competidores, y entrega un informe de inteligencia accionable para el equipo directivo.

**Agente invocado**: `market-analyst` (vía Task tool con `subagent_type`)

**Fase del flujo de agencia**: Investigación de mercado — soporta Phase 1 del flujo creativo y análisis estratégico continuo.

---

## Precondiciones

1. Invocar skill `_core/load-brief` → si falla, abortar y sugerir `/briefing new`.
2. Invocar skill `_core/preflight-check --domains anthropic,telegram` → si hay fallas críticas, abortar y reportar al usuario qué configurar.

---

## Flujo

### Paso 1 — Interpretar argumentos

Parsear `$ARGUMENTS`:

- `$1` = `prices` | `competitors` | `all` (default: `all`)
- `--week-offset N` = analizar semana anterior (ej. `--week-offset 1` para la semana pasada; default: 0 = semana actual)

Normalizar a objeto:

```json
{
  "scope": "prices|competitors|all",
  "week_offset": 0,
  "company": "{COMPANY_NAME}",
  "industry": "{INDUSTRY}",
  "commodities": "{COMMODITIES}",
  "competitors": "{COMPETITORS}"
}
```

### Paso 2 — Delegar al agente vía Task tool

Invocar:

```
Task(
  subagent_type = "market-analyst",
  description   = "Market intelligence report",
  prompt        = <brief cargado> + <args interpretados del Paso 1>
)
```

El agente `market-analyst` es el único responsable de:

- Recopilar precios con WebSearch/WebFetch (Investing.com, IndexMundi, FAO, Fibre2Fashion, etc.).
- Rastrear señales públicas de competidores (noticias, redes, cambios de precio).
- Scoring de amenaza por competidor.
- Redactar el informe con la estructura ejecutivo → precios → competencia → oportunidades → riesgos → recomendaciones.
- Enviar resumen por Telegram si `TELEGRAM_BOT_TOKEN` está configurado.
- Guardar informe completo en `.claude/intel/{FECHA}-market-report.md`.

El command NO ejecuta estas tareas directamente — solo delega.

### Paso 3 — Presentar resultado al usuario

Mostrar en consola el informe devuelto por el agente y la ruta del archivo guardado. Si se envió el resumen por Telegram, confirmar.

---

## Argumentos

| Argumento | Valores | Default | Descripción |
|---|---|---|---|
| `$1` | `prices` \| `competitors` \| `all` | `all` | Qué dimensión investigar |
| `--week-offset` | entero `>=0` | `0` | Desplazamiento en semanas hacia el pasado |

## Ejemplos de uso

```bash
/market-intel                         # Informe completo de la semana actual
/market-intel prices                  # Solo precios
/market-intel competitors             # Solo competencia
/market-intel all --week-offset 1     # Informe completo de la semana pasada
```

## Notas

- Toda la lógica de investigación, scoring y redacción vive en el agente `market-analyst`.
- Datos de precios orientativos (fuentes públicas, no tiempo real).
- Análisis de competencia solo con información públicamente disponible.
- Si falla el preflight de `telegram`, el agente seguirá generando el informe pero no enviará resumen.
