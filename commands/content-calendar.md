---
description: Genera la parrilla mensual de contenido investigando tendencias, cultura y eventos del sector
argument-hint: [YYYY-MM opcional] [--regenerate]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /content-calendar

**Propósito**: Dispara la planeación mensual. Delega al agente `content-planner` la investigación de tendencias, el razonamiento estratégico y la aprobación de la parrilla por Telegram.

**Agente invocado**: `content-planner` (vía Task tool con `subagent_type`)

**Fase del flujo de agencia**: 3 (planeación)

---

## Precondiciones

Antes de delegar al agente, ejecutar en orden:

1. **Cargar brief del cliente activo**
   - Invocar skill `_core/load-brief` → devuelve `brief_json` con `company`, `icp`, `market`, `social.platforms`, `brand`.
   - Si falla: abortar con mensaje `Brief no encontrado. Ejecuta /briefing new para configurar el cliente activo.`

2. **Preflight de credenciales**
   - Invocar skill `_core/preflight-check --domains anthropic,telegram`
   - Si hay fallas críticas (API key faltante, bot token inválido), abortar y mostrar el fix sugerido (`/setup-check`).

---

## Flujo

### Paso 1 — Interpretar argumentos

Parsear `$ARGUMENTS`:

- `$1` (opcional): **target_month** en formato `YYYY-MM`. Si está vacío, calcular el **mes siguiente** al mes actual (`date +%Y-%m` + 1 mes).
- `--regenerate`: forzar regeneración aunque la parrilla ya exista como `approved`. Sin este flag, si existe aprobada, el agente consultará por Telegram antes de sobreescribir.

Validar formato de `$1` (regex `^\d{4}-(0[1-9]|1[0-2])$`). Si es inválido, pedir al usuario que lo corrija y abortar.

### Paso 2 — Delegar al agente vía Task

Invocar el agente con el contexto completo:

```
Task(
  subagent_type: "content-planner",
  description: "Generar parrilla mensual",
  prompt: """
Diseña la parrilla mensual de contenido para el cliente activo.

Entradas:
- brief: {brief_json}
- target_month: {YYYY-MM}
- force_regenerate: {true|false}

Comportamiento esperado (resumido — tu system prompt es la fuente de verdad):
1. Verificar si `.claude/state/calendar/{target_month}.json` ya existe.
   - Si `status == approved` y `force_regenerate == false`:
     preguntar al manager por Telegram antes de regenerar.
   - Si `status == draft`: sobreescribir sin preguntar.
2. Leer historial reciente (`.claude/state/posts/history.json`) y, si existe,
   el último reporte de inteligencia (`.claude/state/intel/*-report.json`).
3. Pedir inputs adicionales al manager por Telegram (eventos confirmados,
   fechas bloqueadas, temas forzados) con timeout de 5 min.
4. Ejecutar las 5 fases de `skills/planning/generate-content-calendar.md`:
   - Investigación de tendencias (WebSearch por plataforma)
   - Eventos sectoriales y culturales
   - Razonamiento estratégico (pilares, rotación, competencia)
   - Generación de la parrilla JSON estructurada
   - Resumen ejecutivo
5. Guardar los 3 artefactos en `.claude/state/calendar/`:
   - `{target_month}.json`           — parrilla con status pending_approval
   - `{target_month}-trends.json`    — insumos de tendencias
   - `{target_month}-summary.md`     — resumen legible
6. Enviar el resumen a Telegram y esperar aprobación
   (sí / editar / rehacer / ver día N) con timeout de 10 min.
7. Si aprobado: actualizar status=approved, approved_at, approved_by=telegram.
8. Si rechazado: dejar status=rejected con motivo.
9. Si timeout: dejar status=pending_approval. El usuario puede aprobar
   después con /check-approvals o re-ejecutar /content-calendar.

Devuelve al terminar:
{
  "status": "approved" | "pending_approval" | "rejected" | "skipped" | "error",
  "target_month": "YYYY-MM",
  "total_entries": N,
  "platforms": ["instagram", "facebook", ...],
  "state_files": [
    ".claude/state/calendar/{YYYY-MM}.json",
    ".claude/state/calendar/{YYYY-MM}-summary.md",
    ".claude/state/calendar/{YYYY-MM}-trends.json"
  ],
  "distribution": { "educational": N, "product": N, ... },
  "notes": "..."
}
"""
)
```

### Paso 3 — Presentar resultado al usuario

Según `status` devuelto por el agente:

- **`approved`**: Confirmar que la parrilla quedó activa. Mostrar `total_entries`, distribución por pilar y rutas de los 3 archivos. Sugerir `/publish-today` cuando llegue el primer día del mes.
- **`pending_approval`**: Informar que el borrador quedó guardado y guiar al manager a responder en Telegram, luego usar `/check-approvals` o re-ejecutar este command.
- **`rejected`**: Mostrar el motivo. Sugerir `/content-calendar {YYYY-MM} --regenerate`.
- **`skipped`**: El manager eligió no regenerar la parrilla ya aprobada. No se tocó nada.
- **`error`**: Mostrar el error. Sugerir `/setup-check` si es credencial.

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | `YYYY-MM` | mes siguiente | Mes objetivo a planificar. |
| `--regenerate` | flag | `false` | Fuerza regeneración aunque la parrilla ya esté aprobada. |

---

## Ejemplo de uso

```
/content-calendar
/content-calendar 2026-11
/content-calendar 2026-11 --regenerate
```

Resultado esperado:

```
Parrilla aprobada para noviembre 2026
  22 publicaciones | IG + FB
  Pilares: educativo 8 · producto 6 · caso 4 · cultura 2 · tendencia 2
  Archivos:
    .claude/state/calendar/2026-11.json
    .claude/state/calendar/2026-11-summary.md
    .claude/state/calendar/2026-11-trends.json
```

---

## Notas

- Este command es **thin**: NO reimplementa la lógica. La investigación de tendencias, razonamiento estratégico y generación del JSON viven en `agents/planner-agent.md` y en `skills/planning/generate-content-calendar.md`.
- La parrilla aprobada es la **fuente de verdad** para `/publish-today` — días sin entrada caen al modo autónomo del publicador.
- Para ajustar entradas puntuales sin regenerar todo, el manager responde `editar: ...` en Telegram durante la aprobación — el agente ya soporta edición incremental.
- Idempotency: el agente usa `_core/state-store` con `key = sha1("calendar:" + target_month)` para evitar generar dos parrillas simultáneas del mismo mes.
