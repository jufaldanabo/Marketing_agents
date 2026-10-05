---
description: Genera y publica respuestas a comentarios en Instagram/Facebook delegando al agente community-manager
argument-hint: "[daily|crisis-only|faq-only] [--platforms X] [--max N]"
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /respond-comments

**Propósito**: Clasifica comentarios públicos en Instagram y Facebook, genera respuestas con la voz de marca, aplica protocolo FAQ y SLA, y publica o escala según corresponda.

**Agente invocado**: `community-manager` (vía Task tool con `subagent_type`).

> **Importante**: antes este command invocaba directamente el skill `respond-comments`. Ahora delega al agente `community-manager`, que absorbió esa lógica más el protocolo FAQ, los SLAs por prioridad y el flujo de escalación. **No se delega al agente `social-monitor`** — ese se encarga de observación/métricas, no de respuesta.

**Fase del flujo de agencia**: 5 (comunidad).

---

## Precondiciones

1. Invocar skill `_core/load-brief` → si falla, abortar y sugerir `/briefing new`.
2. Invocar skill `_core/preflight-check --domains meta,telegram` → si hay fallas críticas, abortar y reportar al usuario qué tokens o permisos reconfigurar (`instagram_manage_comments`, `pages_manage_engagement`, etc.).

---

## Flujo

### Paso 1 — Interpretar argumentos

Parsear `$ARGUMENTS`:

- `$1` = modo (default `daily`):
  - `daily` — procesa todos los comentarios pendientes del día.
  - `crisis-only` — solo urgentes/crisis (quejas públicas, menciones sensibles).
  - `faq-only` — solo preguntas frecuentes resolubles con el protocolo FAQ.
- `--platforms` = filtro de plataforma (`instagram`, `facebook`, o ambas; default: ambas).
- `--max N` = tope de comentarios a procesar en esta corrida (default `20`).

Normalizar a objeto:

```json
{
  "mode": "daily|crisis-only|faq-only",
  "platforms": ["instagram", "facebook"],
  "max": 20,
  "brand_voice": "{brief.BRAND_VOICE o default}",
  "company_name": "{brief.COMPANY_NAME}",
  "industry": "{brief.INDUSTRY}"
}
```

### Paso 2 — Delegar al agente vía Task tool

Invocar:

```
Task(
  subagent_type = "community-manager",
  description   = "Respond to pending social comments",
  prompt        = {
    brief: <brief cargado>,
    args:  <args interpretados del Paso 1>
  }
)
```

El agente `community-manager` es el único responsable de:

- Obtener comentarios pendientes (desde `.claude/reports/{FECHA}.json` o directamente de la Graph API de Meta).
- Clasificación por tipo (consulta comercial, queja, FAQ, spam, elogio, crisis).
- Aplicar SLA por prioridad (urgente < 2h, alta < 6h, media < 24h).
- Aplicar protocolo FAQ (respuestas pre-aprobadas para preguntas recurrentes).
- Generar `public_response` + `private_followup` cuando aplica, en la voz de marca.
- Mostrar preview al usuario y confirmar antes de publicar (opciones A/B/C/D).
- Publicar vía Graph API (`/replies` en IG, `/comments` en FB), ocultar spam, escalar casos sensibles.
- Guardar en `.claude/responses/{FECHA}.json` y notificar escalaciones por Telegram.

El command NO ejecuta estas tareas — solo delega. Toda la lógica anteriormente dispersa en el skill `respond-comments` ya vive dentro del agente `community-manager`.

### Paso 3 — Presentar resultado al usuario

Mostrar el resumen final devuelto por el agente: respuestas publicadas, escaladas, ocultadas, tiempo promedio de respuesta y lista de pendientes para revisión humana con razón de escalación.

---

## Argumentos

| Argumento | Valores | Default | Descripción |
|---|---|---|---|
| `$1` | `daily` \| `crisis-only` \| `faq-only` | `daily` | Modo de procesamiento |
| `--platforms` | `instagram`, `facebook`, o ambas | ambas | Filtro de plataforma |
| `--max` | entero `1-100` | `20` | Tope de comentarios a procesar |

## Ejemplos de uso

```bash
/respond-comments                                   # Modo daily, ambas plataformas, hasta 20
/respond-comments crisis-only                       # Solo urgentes y crisis
/respond-comments faq-only --max 50                 # Hasta 50 FAQs
/respond-comments daily --platforms instagram       # Solo Instagram
/respond-comments daily --platforms facebook --max 10
```

## Notas

- Este command delega al agente `community-manager`, no al skill viejo `respond-comments` ni al agente `social-monitor`.
- El agente siempre pide confirmación antes de publicar (preview + A/B/C/D) salvo que corra en modo no-interactivo desde cron.
- Casos escalados a humano se notifican por Telegram con la razón.
- Spam y contenido ofensivo se ocultan (`is_hidden=true`) sin publicar respuesta.
