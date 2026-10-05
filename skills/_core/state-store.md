---
name: state-store
description: Lectura, escritura y versionado de archivos JSON en .claude/state/ con idempotencia y locking. Punto único para persistencia operacional del toolkit.
allowed-tools: [Read, Write, Edit, Bash]
model: claude-haiku-4-5
---

# Skill: state-store

**Propósito**: Abstracción única para que agentes y skills lean/escriban en `.claude/state/` respetando la estructura definida en `schemas/state-structure.md`. Garantiza idempotencia, locking y auditoría.

**Schema de referencia**: `skills/_core/schemas/state-structure.md`

---

## Operaciones soportadas

| Operación | Propósito |
|---|---|
| `read` | Leer un archivo JSON de state. Falla claro si no existe. |
| `write` | Escribir un archivo JSON de state. Crea directorios intermedios. |
| `append-log` | Agregar línea JSONL a `logs/{agent}/{date}.jsonl`. |
| `acquire-lock` | Crear lock de idempotencia. Falla si ya existe (operación duplicada). |
| `release-lock` | Mover lock a `completed/` tras operación exitosa. |
| `emit-event` | Escribir handoff event a `handoffs/{from}-to-{to}/`. |
| `consume-event` | Marcar un handoff event como procesado. |
| `check-pause` | Verificar si existe `locks/{domain}.lock` → bloqueo manual. |

---

## Flujo por operación

### `read`

**Input**: `path` relativo a `.claude/state/`
**Comportamiento**:
1. Usar tool `Read` sobre `.claude/state/{path}`
2. Si no existe → devolver `{"ok": false, "error": "not_found"}`
3. Si JSON inválido → devolver `{"ok": false, "error": "invalid_json", "detail": "..."}`
4. Si OK → devolver `{"ok": true, "data": <contenido parseado>}`

---

### `write`

**Input**: `path`, `data` (objeto JSON)
**Comportamiento**:
1. Crear directorios intermedios: `mkdir -p .claude/state/$(dirname {path})`
2. Serializar `data` como JSON con indent=2
3. Si el archivo ya existe y `data` NO tiene `updated_at`, agregarlo con `date -u +"%Y-%m-%dT%H:%M:%SZ"`
4. Si el archivo NO existe y `data` NO tiene `created_at`, agregarlo
5. Usar tool `Write` para escribir el archivo
6. Devolver `{"ok": true, "path": "{full-path}"}`

**No sobrescribe silenciosamente** si `data.version` existe y es menor que el del archivo actual — pide confirmación.

---

### `append-log`

**Input**: `agent` (string), `event` (objeto JSON con mínimo `event` y `level`)
**Comportamiento**:
1. Determinar fecha: `date -u +"%Y-%m-%d"`
2. Enriquecer event con:
   - `ts`: timestamp UTC ISO 8601
   - `agent`: nombre del agente
3. Serializar como una línea JSON (sin indent)
4. Append al archivo `.claude/state/logs/{agent}/{YYYY-MM-DD}.jsonl`
5. Crear directorio si no existe

**Ejemplo de línea**:
```json
{"ts":"2026-03-15T10:23:45Z","agent":"content-publisher","level":"info","event":"post_published","platform":"instagram","post_id":"17891...","duration_ms":2340}
```

Use `bash`:
```bash
mkdir -p .claude/state/logs/{agent}
echo '{"ts":"...","agent":"...","level":"info","event":"..."}' >> .claude/state/logs/{agent}/{date}.jsonl
```

---

### `acquire-lock`

**Input**: `operation_key` (string, SHA1[:16] de agent+action+target+content_hash)
**Comportamiento**:
1. Path: `.claude/state/locks/{operation_key}.lock`
2. Si existe:
   - Leer su timestamp. Si tiene <1h → devolver `{"ok": false, "error": "duplicate_operation", "existing": {...}}`
   - Si tiene >1h → considerarlo stale, sobrescribir con warning
3. Crear lock con:
   ```json
   {
     "operation_key": "{key}",
     "agent": "{nombre}",
     "action": "{action}",
     "acquired_at": "ISO timestamp",
     "pid": "{opcional, PID del proceso}"
   }
   ```
4. Devolver `{"ok": true, "lock_path": "..."}`

**Uso**: Antes de operaciones destructivas (publicar, enviar mensaje, crear lead).

---

### `release-lock`

**Input**: `operation_key`, `status` (`"success"` o `"failure"`)
**Comportamiento**:
1. Si `status == "success"`:
   - Mover `.claude/state/locks/{key}.lock` → `.claude/state/locks/completed/{key}.lock`
   - Agregar campo `completed_at`, `status: "success"`
2. Si `status == "failure"`:
   - Mantener en `locks/` para que `/retry-failed` lo procese
   - Agregar campo `failed_at`, `status: "failure"`, `error: "..."`
3. Devolver `{"ok": true}`

---

### `emit-event`

**Input**: `from_agent`, `to_agent`, `event_type`, `severity`, `payload`
**Comportamiento**:
1. Generar `event_id = sha1(timestamp+from+to)[:12]`
2. Path: `.claude/state/handoffs/{from}-to-{to}/{timestamp}-{event_id}.json`
3. Escribir con schema definido en `schemas/state-structure.md`
4. Devolver `{"ok": true, "event_id": "..."}`

---

### `consume-event`

**Input**: `event_path`, `consumed_by` (nombre del agente que lo procesa)
**Comportamiento**:
1. Leer el evento
2. Actualizar: `consumed_at` = ahora, `consumed_by` = agente
3. Reescribir el archivo
4. Devolver `{"ok": true, "payload": {...}}`

---

### `check-pause`

**Input**: `domain` (string: `"posting"`, `"prospecting"`, etc.)
**Comportamiento**:
1. Verificar si existe `.claude/state/locks/{domain}.lock`
2. Si existe:
   - Devolver `{"paused": true, "reason": "...", "since": "..."}`
3. Si no:
   - Devolver `{"paused": false}`

**Uso**: Al inicio de agentes operacionales como `content-publisher` para respetar circuit breakers.

---

## Reglas de implementación

1. **Siempre crear directorios con `mkdir -p`** antes de escribir.
2. **Nunca borrar archivos de state** desde este skill. Solo `/retry-failed` o scripts de retention.
3. **Todos los timestamps en UTC ISO 8601**: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
4. **JSON pretty-print con indent=2** para archivos leídos por humanos, compact para logs JSONL.
5. **IDs son determinísticos**: usar SHA1 de los inputs para que operaciones idempotentes den el mismo ID.

---

## Ejemplo de uso típico

Un publisher que va a publicar un post:

```
1. operation_key = sha1("content-publisher" + "publish-instagram" + "2026-03-15" + content_hash)[:16]
2. check-pause domain=posting → si paused, abortar con mensaje
3. acquire-lock operation_key → si duplicate, abortar
4. [ejecutar operación: llamar a Instagram API]
5. Si éxito:
   - write path=posts/2026-03-15.json data={...}
   - emit-event from=content-publisher to=social-monitor type=post_published payload={...}
   - append-log agent=content-publisher event="post_published"
   - release-lock operation_key status=success
6. Si falla:
   - append-log agent=content-publisher level=error event="publish_failed" error="..."
   - release-lock operation_key status=failure
```

---

## Notas

- Este skill es **síncrono**. No hace network calls.
- Es la única capa que escribe en `.claude/state/`. Agentes NUNCA tocan `.claude/state/` directamente.
- La idempotencia depende de que los agentes calculen bien el `operation_key`. Documentar en cada agente qué va al hash.
