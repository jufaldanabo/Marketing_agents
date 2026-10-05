---
description: Procesa respuestas de aprobación del manager en Telegram y publica borradores aprobados.
argument-hint: [--include-rejected]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /check-approvals

**Propósito**: Consultar el chat de Telegram, parsear la intención (aprobar / editar / rechazar) y ejecutar la acción sobre los borradores pendientes.
**Agente invocado**: `approval-gatekeeper` (vía Task tool)
**Fase del flujo de agencia**: Infraestructura y orquestación (gate entre creación y publicación)

---

## Precondiciones

1. Ejecutar `_core/load-brief` → el brief no es imprescindible para este command, pero sí para resolver `brief.channels` al publicar; si no existe, warning no fatal.
2. Ejecutar `_core/preflight-check --domains telegram` → abortar si no hay `TELEGRAM_BOT_TOKEN` o `TELEGRAM_CHAT_ID`.
3. Verificar que exista `.claude/drafts/` — si está vacío, salir con `✅ No hay borradores pendientes.`

---

## Flujo

### Paso 1 — Parsear argumentos

| Argumento | Significado |
|---|---|
| (vacío) | Procesar aprobaciones/ediciones/rechazos nuevos |
| `--include-rejected` | También incluir en el reporte final los borradores ya rechazados en los últimos 7 días |

### Paso 2 — Delegar al agente vía Task

Invocar `approval-gatekeeper`:

```
Task tool:
  subagent_type: "approval-gatekeeper"
  prompt: |
    SCOPE: process_pending_approvals
    INCLUDE_REJECTED: {true | false}
    DRAFTS_DIR: .claude/drafts/
    OFFSET_FILE: .claude/drafts/_telegram_offset.json

    1. Leer todos los drafts con status="pending_approval".
    2. GET /getUpdates con offset actual.
    3. Clasificar cada mensaje:
       - APROBACIÓN  → publicar en platforms del draft (ig/fb/tiktok)
       - EDICIÓN     → regenerar con claude-opus-4-7, crear nuevo draft, re-enviar aprobación
       - RECHAZO     → marcar rejected + motivo
       - AMBIGUO     → responder en Telegram pidiendo draft_id si hay >1 pendiente
    4. Actualizar _telegram_offset.json con max(update_id)+1.
    5. Notificar en Telegram cada acción ejecutada.
    6. Si hay drafts con >48h sin respuesta, enviar recordatorio.
    7. Devolver resumen JSON:
       {
         "published": [draft_ids],
         "edited":    [{old, new}],
         "rejected":  [{draft_id, reason}],
         "pending":   [{draft_id, hours_waiting}],
         "errors":    [...]
       }
```

### Paso 3 — Presentar resultado

```
## /check-approvals — {TIMESTAMP}

Borradores revisados: {N}
✅ Publicados: {N}   → {IDS}
✍️ Editados:   {N}   → {IDS} (nuevos borradores enviados)
❌ Rechazados: {N}   → {IDS}
⏳ Pendientes: {N}   → {IDS} (el más viejo lleva {H}h)
```

Si falló alguna publicación tras aprobar, mostrar los errores y mantener el draft como `publish_failed` para reintentos con `--force {ID}` (modo manual del agente).

---

## Argumentos

```bash
/check-approvals                       # Flujo normal (cada 10 min en Railway)
/check-approvals --include-rejected    # Incluir rechazados recientes en el reporte
```

## Ejemplo

```
/check-approvals
→ approval-gatekeeper procesa 3 mensajes de Telegram
→ 1 aprobación ("dale") → publica draft a3f9c21b en IG+FB
→ 1 edición ("hazlo más corto") → genera nuevo draft 7b2e, re-envía
→ 1 rechazo ("mejor no") → marca draft c1d4 como rejected
→ offset actualizado
```

## Notas

- Este command se programa en Railway cada 10 min (`*/10 * * * *`) — ver `/setup-railway`.
- La lógica de parseo de lenguaje natural (sí / dale / ok / editar / rechazar), publicación multi-plataforma, regeneración con instrucciones del manager, offset tracking y recordatorios vive **toda** dentro del agente `approval-gatekeeper`.
- Si falta un `draft_id` cuando hay múltiples pendientes, el agente responde en Telegram pidiendo clarificación — no actualiza el offset para no perder el mensaje.
