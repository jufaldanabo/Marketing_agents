---
description: Reporte nocturno de comentarios, DMs, menciones y métricas de redes sociales enviado por Telegram
argument-hint: [YYYY-MM-DD opcional] [--platforms ig,fb,tt] [--dry-run]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /social-report

**Propósito**: Dispara el reporte nocturno de monitoreo. Delega al agente `social-monitor` la recolección de comentarios/DMs/métricas, el análisis y el envío por Telegram.

**Agente invocado**: `social-monitor` (vía Task tool con `subagent_type`)

**Fase del flujo de agencia**: 6 (monitoreo)

---

## Precondiciones

Antes de delegar al agente, ejecutar en orden:

1. **Cargar brief del cliente activo**
   - Invocar skill `_core/load-brief` → devuelve `brief_json` con `company`, `social.platforms` activas.
   - Si falla: abortar con mensaje `Brief no encontrado. Ejecuta /briefing new para configurar el cliente activo.`

2. **Preflight de credenciales**
   - Invocar skill `_core/preflight-check --domains meta,telegram`
   - Si hay fallas críticas (tokens Meta expirados o Telegram inválido), abortar y mostrar el fix (`/setup-check`).

---

## Flujo

### Paso 1 — Interpretar argumentos

Parsear `$ARGUMENTS`:

- `$1` (opcional): **date** en formato `YYYY-MM-DD`. Si está vacío, usar hoy (`date +%Y-%m-%d`).
- `--platforms ig,fb,tt`: filtrar plataformas a revisar. Default: todas las activas en `brief.social.platforms`.
- `--dry-run`: generar el reporte y guardarlo en `.claude/state/reports/{date}.md` pero NO enviar a Telegram.

Validar formato de `$1` (regex `^\d{4}-\d{2}-\d{2}$`). Si es inválido, pedir corrección y abortar.

### Paso 2 — Delegar al agente vía Task

Invocar el agente con el contexto completo:

```
Task(
  subagent_type: "social-monitor",
  description: "Reporte nocturno de redes",
  prompt: """
Genera el reporte diario de monitoreo social del cliente activo.

Entradas:
- brief: {brief_json}
- target_date: {YYYY-MM-DD}
- platforms: {["instagram", "facebook", "tiktok"] filtradas por --platforms}
- dry_run: {true|false}

Comportamiento esperado (resumido — tu system prompt es la fuente de verdad):
1. Para cada plataforma activa, recolectar vía Graph API / TikTok API:
   - Posts de las últimas 24h (comments_count, reactions)
   - Comentarios y replies por post
   - DMs / mensajes de página
   - Insights del día (reach, impressions, engagement, follower_count)
2. Verificar expiración de tokens Meta (skill `social_monitoring/check-token-expiry`).
   Emitir evento `token_expiring` si <10 días.
3. Clasificar comentarios en prioridades (alta: queja/consulta de venta; media: duda;
   baja: emoji/felicitación) usando claude-sonnet-4-6.
4. Detectar señales de crisis (pico de menciones negativas, viralización negativa).
   Emitir evento `crisis_detected` si corresponde.
5. Generar reporte ejecutivo con las 7 secciones estándar
   (resumen, comentarios pendientes, DMs, métricas vs ayer, oportunidades,
    alertas, acciones para mañana) — máx 500 palabras.
6. Guardar en `.claude/state/reports/{target_date}.md`.
7. Si dry_run=false, enviar el reporte formateado a Telegram.
   Si dry_run=true, solo guardar el archivo y marcarlo como preview.

Devuelve al terminar:
{
  "status": "sent" | "dry_run" | "partial" | "error",
  "target_date": "YYYY-MM-DD",
  "platforms_checked": ["instagram", "facebook", ...],
  "platforms_failed": [],
  "counts": {
    "comments_pending": N,
    "dms_pending": N,
    "high_priority": N,
    "crisis_signals": N
  },
  "metrics_delta": { "reach": "+12%", "followers": "+3", ... },
  "events_emitted": ["token_expiring", "crisis_detected"],
  "state_files": [".claude/state/reports/{date}.md"]
}
"""
)
```

### Paso 3 — Presentar resultado al usuario

Según `status` devuelto por el agente:

- **`sent`**: Confirmar envío a Telegram. Mostrar counts (comentarios pendientes, alta prioridad, señales de crisis) y métricas delta. Sugerir `/respond-comments` si hay comentarios pendientes de alta prioridad.
- **`dry_run`**: Confirmar que el reporte quedó en disco pero no se envió. Mostrar ruta del `.md`.
- **`partial`**: Mostrar qué plataformas fallaron. Sugerir `/setup-check` para la plataforma caída.
- **`error`**: Mostrar el error exacto. Si fue token: `/setup-check`. Si fue red: reintentar.

Si el agente emitió `token_expiring` o `crisis_detected`, resaltar en la respuesta al usuario (son los eventos más importantes).

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | `YYYY-MM-DD` | hoy | Fecha del reporte. |
| `--platforms` | lista | todas activas | Filtra plataformas (`ig`, `fb`, `tt`). |
| `--dry-run` | flag | `false` | Genera el reporte pero no lo envía a Telegram. |

---

## Ejemplo de uso

```
/social-report
/social-report 2026-10-04
/social-report --platforms ig,fb
/social-report --dry-run
```

Resultado esperado:

```
Reporte enviado por Telegram
  Fecha: 2026-10-05
  Comentarios pendientes: 7 (3 alta prioridad)
  DMs: 2 nuevos
  Reach IG: +12% vs ayer
  Eventos: token_expiring (FB caduca en 8 días)
  Archivo: .claude/state/reports/2026-10-05.md
```

---

## Notas

- Este command es **thin**: NO reimplementa la lógica. Las llamadas a Graph API, clasificación de comentarios, detección de crisis y verificación de tokens viven en `agents/monitoring-agent.md` y en los skills bajo `skills/social_monitoring/*`.
- Programación automática: Railway cron ~22:00 (ver `/setup-railway`). El agente ya está diseñado para ejecutarse de forma no-interactiva.
- Idempotency: el agente usa `_core/state-store` con `key = sha1("report:" + target_date)` para evitar generar dos reportes del mismo día; si se re-ejecuta, actualiza el existente.
- Para responder a los comentarios flagged, usar `/respond-comments` (flujo separado con aprobación por Telegram).
