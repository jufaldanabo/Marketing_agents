---
description: Pausa toda la publicación automática del cliente — crea un circuit breaker que content-publisher respeta. Útil durante crisis, períodos de inactividad o revisión estratégica.
argument-hint: [razón opcional]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /pause-posting

**Propósito**: Circuit breaker manual. Mientras exista `.claude/state/locks/posting.lock`, `content-publisher` aborta cualquier intento de publicar.

**Agente invocado**: `conductor` (modo `pause-posting`)

**Fase del flujo de agencia**: **Circuit breaker cross-fase**

---

## Cuándo ejecutar

- **Crisis de reputación**: antes de que el community-manager tenga que escalar
- **Períodos de inactividad del cliente**: vacaciones, cierre temporal
- **Revisión estratégica**: cuando el cliente decide ajustar enfoque y no quiere publicar genérico
- **Problemas técnicos**: credenciales por renovar, tokens inválidos
- **Testing**: durante onboarding de nuevo cliente antes de ir a producción

**Nota**: El `conductor` también crea este lock **automáticamente** cuando detecta eventos `crisis_detected` o `token_expiring` con <1 día.

---

## Precondiciones

1. `_core/load-brief` → debe haber brief del cliente activo

---

## Flujo

### Paso 1 — Capturar razón

- Si se pasó `$1` o `$ARGUMENTS` → usar como razón
- Si no → preguntar al usuario:
  ```
  ¿Por qué quieres pausar la publicación?
  Ejemplos:
    - "Vacaciones del cliente hasta 15 abril"
    - "Esperando aprobación de nuevo brand kit"
    - "Crisis de reputación — en reunión con el cliente"
    - "Testing"
  ```

### Paso 2 — Delegar al conductor

```
Task(
  subagent_type: "conductor",
  description: "Pause posting circuit breaker",
  prompt: """
    Modo: pause-posting
    Razón: {razón del usuario}

    Crea .claude/state/locks/posting.lock con:
      - reason: "manual"
      - created_at: ISO
      - created_by: "humano via /pause-posting"
      - manual_message: {razón}

    Envía confirmación por Telegram y reporta el estado al usuario.
  """
)
```

### Paso 3 — Presentar resultado

```
🚫 PUBLICACIÓN PAUSADA

Razón: {razón}
Pausado desde: {timestamp}

Mientras exista el lock:
  • /publish-today y /daily skippearán la publicación
  • Las ejecuciones del Railway cron también
  • community-manager seguirá operando normalmente
  • Reportes y análisis siguen activos

📧 Confirmación enviada por Telegram.

Para reanudar: /resume-posting
```

---

## Argumentos

| Arg | Tipo | Descripción |
|---|---|---|
| `$1` | string | Razón de la pausa (opcional, se pregunta si falta) |

---

## Ejemplos de uso

```
/pause-posting
/pause-posting "Vacaciones hasta 15 abril"
/pause-posting "Crisis en reunión con PR"
```

---

## Lo que sigue funcionando con pause activa

| Función | Estado |
|---|---|
| Publicación en IG/FB/TikTok | ❌ Pausada |
| Pauta activa (campañas corriendo) | ⚠️ Siguen corriendo (necesitas pausar manualmente en Ads Manager) |
| Community manager (comentarios/DMs) | ✅ Sigue |
| Social monitor (reportes) | ✅ Sigue |
| Performance analyst | ✅ Sigue |
| Market analyst | ✅ Sigue |
| Prospecting | ✅ Sigue (usa `prospecting.lock` para pausar) |

Si quieres pausar TAMBIÉN la pauta, debes hacerlo manualmente en Meta Ads Manager o TikTok Ads Manager (el toolkit no tiene control programático de pausa de ads).

---

## Notas

- La pausa es **persistente** hasta que se corra `/resume-posting`
- Se guarda historial de pausas en `.claude/state/locks/history/`
- Si el conductor creó el lock automáticamente por crisis, se puede quitar con `/resume-posting` (requiere confirmación)
