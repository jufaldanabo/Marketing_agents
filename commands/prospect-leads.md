---
description: Busca, califica y prepara contacto con prospectos B2B delegando al agente sales-prospector
argument-hint: "[count] [--industry X] [--geography Y]"
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /prospect-leads

**Propósito**: Entrega una lista de prospectos B2B calificados con mensajes de primer contacto personalizados, listos para que el vendedor revise y envíe.

**Agente invocado**: `sales-prospector` en modo `prospect` (vía Task tool con `subagent_type`)

**Fase del flujo de agencia**: Auxiliar B2B — no forma parte del flujo creativo principal, pero se mantiene como capacidad lateral del toolkit.

---

## Precondiciones

1. Invocar skill `_core/load-brief` → si falla, abortar y sugerir `/briefing new`.
2. Invocar skill `_core/preflight-check --domains anthropic,telegram` → si hay fallas críticas, abortar y reportar al usuario qué configurar.

---

## Flujo

### Paso 1 — Interpretar argumentos

Parsear `$ARGUMENTS`:

- `$1` = `count` (entero, default `10`) — cantidad objetivo de leads calificados.
- `--industry X` = override opcional de `INDUSTRY_TARGET` del brief.
- `--geography Y` = override opcional de `GEOGRAPHY` del brief.

Normalizar a objeto:

```json
{
  "mode": "prospect",
  "count": 10,
  "industry_target": "{override o brief.INDUSTRY_TARGET}",
  "geography": "{override o brief.GEOGRAPHY}",
  "product": "{brief.PRODUCT}",
  "sender_name": "{brief.SENDER_NAME}",
  "sender_role": "{brief.SENDER_ROLE}",
  "company_name": "{brief.COMPANY_NAME}"
}
```

Si faltan datos críticos del brief (PRODUCT, SENDER_NAME, etc.), avisar al usuario y sugerir completar `/briefing`.

### Paso 2 — Delegar al agente vía Task tool

Invocar:

```
Task(
  subagent_type = "sales-prospector",
  description   = "Prospect qualified B2B leads",
  prompt        = {
    mode: "prospect",
    brief: <brief cargado>,
    args: <args interpretados del Paso 1>
  }
)
```

El agente `sales-prospector` (modo `prospect`) es el único responsable de:

- Construir y confirmar el ICP.
- Búsqueda de empresas candidatas vía WebSearch/WebFetch (directorios, LinkedIn, gremios, ferias).
- Detección de señales de compra (triggers).
- Calificación 0-100 por dimensión (ajuste 40%, intención 35%, accesibilidad 25%) y clasificación Hot/Warm/Cold.
- Generación de mensajes personalizados (LinkedIn + email) con variantes para Hot Leads.
- Guardado en `.claude/leads/{FECHA}/` (leads.json, hot-leads.json, outreach/*.md, report.md).
- Notificación opcional por Telegram.

El command NO ejecuta ninguna de estas tareas — solo delega al agente en modo `prospect` (distinto del modo `followup` usado por `/followup-leads`).

### Paso 3 — Presentar resultado al usuario

Mostrar el reporte final devuelto por el agente con el resumen (empresas evaluadas, Hot/Warm/Cold counts), los Hot Leads con sus mensajes listos para copiar, y las rutas de archivos guardados.

---

## Argumentos

| Argumento | Valores | Default | Descripción |
|---|---|---|---|
| `$1` | entero `1-50` | `10` | Cantidad objetivo de leads calificados |
| `--industry` | string | brief | Override del sector objetivo |
| `--geography` | string | brief | Override de la geografía objetivo |

## Ejemplos de uso

```bash
/prospect-leads                                          # 10 leads con brief actual
/prospect-leads 15                                       # 15 leads con brief actual
/prospect-leads 10 --industry "fabricantes de ropa"      # Override de sector
/prospect-leads 20 --geography "México"                  # Override de geografía
/prospect-leads 10 --industry "hoteles" --geography "CO" # Combinación
```

## Notas

- Toda la lógica de búsqueda, scoring, generación de mensajes y guardado vive en el agente `sales-prospector`.
- Calidad > cantidad: 10 leads reales valen más que 100 genéricos.
- Solo información públicamente disponible — no scraping de bases de datos privadas.
- Los mensajes son plantillas personalizadas — el vendedor debe revisarlos antes de enviar.
- Para seguimiento a leads sin respuesta, usar `/followup-leads` (invoca el mismo agente en modo `followup`).
