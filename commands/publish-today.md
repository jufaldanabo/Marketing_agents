---
description: Genera y publica el contenido B2B del día en Instagram, Facebook (y TikTok si aplica) con aprobación por Telegram
argument-hint: [topic opcional] [--dry-run] [--retry]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /publish-today

**Propósito**: Dispara la publicación diaria. Delega todo el flujo (parrilla → copy → imagen → aprobación → publicación) al agente `content-publisher`.

**Agente invocado**: `content-publisher` (vía Task tool con `subagent_type`)

**Fase del flujo de agencia**: 5 (publicación)

---

## Precondiciones

Antes de delegar al agente, ejecutar en orden:

1. **Cargar brief del cliente activo**
   - Invocar skill `_core/load-brief` → devuelve `brief_json` con `company`, `icp`, `market`, `social`, `brand`.
   - Si falla: abortar con mensaje `Brief no encontrado. Ejecuta /briefing new para configurar el cliente activo.`

2. **Preflight de credenciales**
   - Invocar skill `_core/preflight-check --domains anthropic,meta,telegram`
   - Si la parrilla o el usuario indican que hoy se publica también en TikTok, añadir `tiktok` a la lista de dominios.
   - Si hay fallas críticas (token faltante, expirado o inválido), abortar y mostrar la lista de dominios en rojo con el fix sugerido (`/setup-check` o `/plugin reconfigure`).

3. **Comprobar pausa de dominio**
   - Invocar skill `_core/state-store check-pause --domain posting`
   - Si está pausado: abortar con el motivo y hora de reanudación. No invocar al agente.

---

## Flujo

### Paso 1 — Interpretar argumentos

Parsear `$ARGUMENTS`:

- `$1` (opcional): **topic override** — si el usuario escribe `/publish-today "lanzamiento nueva línea"`, ese string se pasa al agente como `topic_override` y tiene prioridad sobre la parrilla.
- `--dry-run`: generar borrador y previsualizar en Telegram pero NO publicar en Meta/TikTok aunque sea aprobado. Útil para probar.
- `--retry`: reintentar el último borrador fallido (`.claude/state/drafts/*.json` con `status != published`). Si no hay borrador reciente, informar y abortar.

Si falta algo crítico (ej. `--retry` sin borradores pendientes), responder al usuario antes de delegar.

### Paso 2 — Delegar al agente vía Task

Invocar el agente con el contexto completo:

```
Task(
  subagent_type: "content-publisher",
  description: "Publicar contenido del día",
  prompt: """
Ejecuta tu flujo completo de publicación diaria para el cliente activo.

Entradas:
- brief: {brief_json}
- today: {YYYY-MM-DD}
- topic_override: {$1 o null}
- dry_run: {true|false}
- retry_draft_id: {draft_id si --retry, else null}

Comportamiento esperado (resumido — tu system prompt es la fuente de verdad):
1. Leer la parrilla mensual aprobada (.claude/state/calendar/{YYYY-MM}.json).
   Si hay entrada para hoy, úsala. Si no, selección autónoma según historial.
   topic_override, si existe, prevalece sobre todo lo demás.
2. Preguntar al manager por Telegram (foto propia vs generar con IA) y
   resolver intención en lenguaje natural (ver tu system prompt).
3. Enrutar según artifact_type (post | historia | carousel | reel | tiktok)
   al skill correspondiente de `skills/publishing/*`.
4. Enviar preview a Telegram y esperar aprobación (sí/editar/no).
5. Si dry_run=true, NO publicar aunque sea aprobado — solo marcar el draft
   como `dry_run_approved` y terminar.
6. Si dry_run=false y aprobado, publicar en IG/FB (y TikTok si aplica),
   actualizar historial e invariantes de `_core/state-store`.
7. Confirmar en Telegram y devolver el resumen estructurado.

Devuelve al terminar:
{
  "status": "published" | "dry_run" | "rejected" | "timeout" | "error",
  "draft_id": "...",
  "topic": "...",
  "source": "parrilla|argumento|calendario|autónomo",
  "artifact_type": "post|carousel|reel|historia|tiktok",
  "platforms": { "instagram": {...}, "facebook": {...}, "tiktok": {...} },
  "state_files": [".claude/state/posts/{fecha}.json", ...],
  "next_suggestion": "..."
}
"""
)
```

### Paso 3 — Presentar resultado al usuario

Según `status` devuelto por el agente:

- **`published`**: Mostrar IDs de posts por plataforma, `draft_id`, tópico y ruta al archivo en `.claude/state/posts/{fecha}.json`. Sugerir `/social-report` esa noche.
- **`dry_run`**: Confirmar que el borrador quedó listo pero no se publicó. Mostrar ruta del draft y sugerir re-ejecutar sin `--dry-run` o aprobar vía `/check-approvals`.
- **`rejected`**: Mostrar el motivo del manager. Sugerir `/publish-today` con otro topic o `/content-calendar --regenerate` si el problema es la parrilla.
- **`timeout`**: El borrador quedó pendiente. Guiar al usuario a `/check-approvals` para publicar más tarde.
- **`error`**: Mostrar el error exacto. Sugerir `/setup-check` si es un token y `--retry` si fue una falla de red.

Mostrar también la ruta de los archivos en `.claude/state/...` que el agente escribió (historial, draft, imagen).

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | string | — | Topic override. Si está presente, prevalece sobre la parrilla. |
| `--dry-run` | flag | `false` | Genera y aprueba borrador pero NO publica en Meta/TikTok. |
| `--retry` | flag | `false` | Reintenta el último borrador aprobado que no logró publicarse. |

---

## Ejemplo de uso

```
/publish-today
/publish-today "casos de éxito con cliente textil peruano"
/publish-today --dry-run
/publish-today --retry
```

Resultado esperado (modo normal, día con parrilla aprobada):

```
Borrador abc12345 publicado
  Instagram: 17912...
  Facebook:  10215...
  Tópico:    Trazabilidad en la cadena textil (parrilla)
  Siguiente: /social-report esta noche
```

---

## Notas

- Este command es **thin**: NO reimplementa la lógica del flujo. Toda la lógica (parrilla, generación de imagen vía fal.ai, polling de Telegram, publicación en Graph API, actualización de historial) vive en `agents/publisher-agent.md` y en los skills bajo `skills/publishing/*`.
- Si necesitas inspeccionar o modificar el flujo interno, lee `agents/publisher-agent.md`.
- Para operaciones duplicadas (misma fecha, mismo topic), el agente usa `_core/state-store` con `idempotency_key = sha1(date + topic + platform)`.
- Para publicar un borrador que quedó pendiente por timeout, usa `/check-approvals` — no requiere re-ejecutar este command.
