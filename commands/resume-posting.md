---
description: Reanuda la publicación automática del cliente eliminando el circuit breaker. Si el lock fue creado automáticamente por crisis, pide confirmación extra.
argument-hint: [--force]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /resume-posting

**Propósito**: Levantar el circuit breaker de publicación. Después de este command, `content-publisher` vuelve a operar normalmente.

**Agente invocado**: `conductor` (modo `resume-posting`)

**Fase del flujo de agencia**: **Circuit breaker cross-fase**

---

## Cuándo ejecutar

- **Fin de pausa manual**: el cliente volvió de vacaciones, la crisis se resolvió
- **Después de crisis**: validar que la situación esté bajo control antes de reanudar
- **Después de renovar tokens**: cuando el conductor pausó por `token_expiring`
- **Después de actualizar brand kit**: cuando pausaste para revisar

---

## Precondiciones

1. `_core/load-brief` → debe haber brief
2. Debe existir `.claude/state/locks/posting.lock` — si no, informar que ya está activo

---

## Flujo

### Paso 1 — Verificar lock

Si no existe `locks/posting.lock`:
```
✅ La publicación ya está activa.
No hay lock que remover.
```
Terminar.

### Paso 2 — Leer el lock y evaluar origen

Cargar el lock. Si `reason != "manual"` (ej. `"crisis_detected"`, `"token_expiring"`):

```
⚠️ El lock fue creado AUTOMÁTICAMENTE por: {reason}

Detalles:
{details del lock}

Creado: {created_at}

¿Confirmas que ya resolviste el issue y quieres reanudar? (sí / no)
```

Si usuario pasa `--force`, saltar esta confirmación.

### Paso 3 — Delegar al conductor

```
Task(
  subagent_type: "conductor",
  description: "Resume posting circuit breaker",
  prompt: """
    Modo: resume-posting

    Pipeline:
    1. Mover .claude/state/locks/posting.lock → .claude/state/locks/history/{timestamp}-posting.lock
    2. Agregar al lock movido campo "resumed_at" y "resumed_by"
    3. Enviar confirmación por Telegram
    4. Si el lock era por crisis, registrar en log con duración de la pausa

    Reporta: cuánto duró la pausa + estado actual.
  """
)
```

### Paso 4 — Presentar resultado

```
✅ PUBLICACIÓN REANUDADA

Lock removido: {reason original}
Duración de la pausa: {duration}
Reanudado por: {usuario}

🤖 ESTADO ACTUAL
  Posting: ✅ ACTIVO
  Próximo ciclo: {next_scheduled_run}

📧 Confirmación enviada por Telegram.

Si hoy tocaba publicar según la parrilla y aún no has publicado:
  → Ejecuta /publish-today para publicar ahora
```

---

## Argumentos

| Arg | Tipo | Descripción |
|---|---|---|
| `--force` | flag | Omitir confirmación si el lock era automático |

---

## Ejemplos de uso

```
/resume-posting                 # con confirmación si fue crisis
/resume-posting --force         # sin confirmación
```

---

## Validación post-reanudación

Después de ejecutar, verificar que:
1. El lock está en `history/`, no en `locks/`
2. El próximo cron de `/daily` o `/publish-today` ejecutará normalmente
3. El evento `posting_paused` (si existía) ya no bloquea publisher

---

## Comandos relacionados

- `/pause-posting` — crear circuit breaker
- `/daily --dry-run` — verificar que publisher correría si tocara
- `/dashboard` — ver estado completo del toolkit
