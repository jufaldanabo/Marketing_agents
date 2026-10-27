---
description: Pre-produce todo el contenido del mes de una vez — copy + imágenes generadas y aprobadas, listas para que /publish-today solo publique
argument-hint: [YYYY-MM] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--dry-run]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /batch-produce

**Propósito**: Genera y aprueba por adelantado el contenido de todos los posts del calendario mensual. Separa la producción de la publicación — `/publish-today` solo sube lo que ya está listo.

**Agente invocado**: `content-publisher` (modo `produce`) vía Task tool

**Fase del flujo de agencia**: 4→5 (bisagra entre producción y publicación)

---

## Por qué existe este command

El flujo default de `/publish-today` genera y publica el mismo día. Esto funciona, pero:
- Requiere que el cliente apruebe contenido bajo presión de tiempo
- No permite revisar imágenes con calma ni pedir fotos reales con anticipación
- Bloquea la operación si hay un problema con fal.ai o Telegram el día de publicación

`/batch-produce` resuelve esto: produces todo el mes en una sesión tranquila, apruebas cada pieza en Telegram, y el día de publicación `/publish-today` solo ejecuta el upload a las APIs.

---

## Precondiciones

1. **Cargar brief**
   - Invocar `_core/load-brief` → si falla, abortar con `Brief no encontrado. Ejecuta /briefing new.`

2. **Verificar calendario aprobado**
   - Leer `.claude/state/calendar/{YYYY-MM}.json`
   - Si no existe o `status != "approved"` → abortar con `Parrilla no encontrada para {mes}. Ejecuta /content-calendar primero.`

3. **Preflight parcial** (solo producción — no Meta/TikTok todavía)
   - Invocar `_core/preflight-check --domains anthropic,fal`
   - Si `anthropic` falla → abortar (sin API key no hay generación)
   - Si `fal` falla → continuar pero marcar posts que necesitan imagen como `pending_asset` en vez de generarla

4. **Comprobar pausa**
   - `_core/state-store check-pause --domain production`
   - Si está pausado → abortar con motivo

---

## Flujo

### Paso 1 — Parsear argumentos

`$ARGUMENTS` acepta:

- `$1` (opcional): mes en formato `YYYY-MM`. Default: mes actual.
- `--from YYYY-MM-DD`: producir solo desde esta fecha inclusive.
- `--to YYYY-MM-DD`: producir solo hasta esta fecha inclusive.
- `--dry-run`: genera copy pero NO llama a fal.ai ni a Telegram. Útil para validar el flujo.

Si `$1` no es una fecha válida, informar y usar el mes actual.

### Paso 2 — Leer calendario e identificar pendientes

Cargar `.claude/state/calendar/{YYYY-MM}.json` y filtrar entries donde:
- `date` está dentro del rango solicitado
- NO existe ya un draft en `.claude/state/drafts/{draft_id}.json` con `status: ready`

Presentar al usuario el resumen antes de empezar:

```
Producción batch — Noviembre 2026
  14 posts en parrilla
   2 ya tienen draft listo (se omiten)
  12 a producir ahora

  Estimado: ~8 min (fal.ai + aprobaciones Telegram)
  ¿Continuar? (s/n)
```

Si el usuario responde `n` → abortar limpiamente.

### Paso 3 — Producir en lotes

Para cada entry pendiente, invocar el agente en modo produce:

```
Task(
  subagent_type: "content-publisher",
  description: "Producir borrador {date} — {topic}",
  prompt: """
Ejecuta en modo PRODUCE (no publicar) para el siguiente entry de la parrilla.

Contexto:
- brief: {brief_json}
- brand_kit: {brand_kit_json}
- mode: "produce"
- entry: {entry_json}
- dry_run: {true|false}

Comportamiento esperado:
1. Generar copy para cada plataforma del entry (según format y pillar).
2. Si el entry requiere imagen AI → generar con fal.ai y adjuntar URL al draft.
3. Si el entry requiere foto real → no generar imagen; marcar draft como pending_asset
   e incluir en el campo `asset_brief` la descripción exacta de qué foto/video necesitas.
4. Enviar preview a Telegram para aprobación humana (copy + imagen si aplica).
5. Según respuesta:
   - approve → guardar draft con status: "ready"
   - edit    → aplicar cambios y re-enviar a Telegram (máximo 2 rondas)
   - reject  → guardar draft con status: "rejected", continuar con el siguiente
   - timeout → guardar draft con status: "pending_approval", continuar
6. NO invocar publish-instagram, publish-facebook ni publish-tiktok.

Draft a escribir en .claude/state/drafts/{draft_id}.json:
{
  "draft_id": "...",
  "date": "YYYY-MM-DD",
  "topic": "...",
  "pillar": "...",
  "format": "...",
  "platforms": [...],
  "content": {
    "instagram": {"caption": "...", "image_url": "..." },
    "facebook":  {"message": "...",  "image_url": "..." },
    "tiktok":    {"caption": "...",  "script": "...",   "image_url": "..."}
  },
  "asset_brief": null,
  "status": "ready" | "pending_asset" | "pending_approval" | "rejected",
  "produced_at": "ISO-8601",
  "approved_by": "telegram"
}

Devuelve al terminar:
{
  "draft_id": "...",
  "date": "...",
  "topic": "...",
  "status": "ready" | "pending_asset" | "pending_approval" | "rejected",
  "asset_brief": null | "descripción de qué foto/video necesitas",
  "image_url": "..." | null
}
"""
)
```

Procesar los entries secuencialmente para no saturar la API de fal.ai ni la bandeja de Telegram del cliente.

### Paso 4 — Presentar resumen final

Al terminar todos los entries, mostrar en pantalla:

```
Producción batch completada — Noviembre 2026
────────────────────────────────────────────
  ✅ Listos para publicar:     10 posts
  📷 Esperando foto/video:      2 posts
  ⏳ Pendiente de aprobación:   1 post
  ❌ Rechazados:                1 post

Posts que necesitan asset físico:
  • Nov 15 — "Proceso de acabado en planta" → foto del área de producción
  • Nov 22 — "Reel del producto en uso"     → video 15-30s del producto en manos del cliente

Siguiente paso:
  • Manda las fotos/videos al bot de Telegram — te preguntará para cuál fecha son
  • Para publicar hoy si hay algo listo → /publish-today
  • Para revisar aprobaciones pendientes → /check-approvals
```

### Paso 4B — Notificar assets pendientes por Telegram

Si hay posts con `status: pending_asset`, invocar `_core/telegram-notify` con:

```
📦 Producción de {MES} lista.

{Si pending_asset > 0:}
Necesito {N} archivo(s) físico(s) para completar el mes:

{Para cada draft con pending_asset, en orden de fecha:}
📸 {D MMM} — "{topic}"
   {asset_brief}

Envíame cada archivo directamente aquí.
Te preguntaré para cuál fecha es y lo dejo listo para publicar automáticamente.

{Si pending_asset == 0:}
✅ Todo el contenido del mes está listo y aprobado. No necesito nada más de tu parte.
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | YYYY-MM | mes actual | Mes a producir |
| `--from` | YYYY-MM-DD | inicio del mes | Producir desde esta fecha |
| `--to` | YYYY-MM-DD | fin del mes | Producir hasta esta fecha |
| `--dry-run` | flag | false | Simula el flujo sin llamar a fal.ai ni Telegram |

---

## Ejemplos de uso

```
/batch-produce                          → produce todo el mes actual
/batch-produce 2026-11                  → produce noviembre
/batch-produce --from 2026-11-15        → produce desde el 15
/batch-produce 2026-11 --dry-run        → simula sin gastar en fal.ai
/batch-produce --from 2026-11-15 --to 2026-11-15  → re-produce un solo día
```

---

## Notas

- Este command es **thin**: la generación de copy e imágenes ocurre en `content-publisher` (modo `produce`). Este command solo orquesta el loop, filtra pendientes y presenta el resumen.
- Los drafts con `status: ready` son consumidos automáticamente por `/publish-today` — no hace falta ninguna acción extra el día de publicación.
- Para posts con `status: pending_asset`: subir la foto/video a `.claude/brand-images/products/` y re-ejecutar `/batch-produce` solo para esa fecha con `--from`/`--to`.
- Idempotente: si ya existe un draft `ready` para una fecha, no lo regenera. Pasarlo a `--force` si necesitas regenerar (no implementado en v1, hacerlo manualmente borrando el draft).
