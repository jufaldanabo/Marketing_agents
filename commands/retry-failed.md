---
description: Reintenta operaciones que fallaron previamente (publicaciones no publicadas, mensajes no enviados, aprobaciones en limbo). Lee los locks fallidos y les da otra oportunidad.
argument-hint: [--domain publishing|community|ads|all] [--dry-run]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /retry-failed

**Propósito**: Rescate de operaciones que quedaron en estado `failure` o `limbo` por fallos transitorios (API caída, token expirado, timeout de red). Lee los locks sin cerrar y los reintenta.

**Agente invocado**: `conductor` (modo custom `retry-failed`)

**Fase del flujo de agencia**: **Resiliencia / infraestructura**

---

## Cuándo ejecutar

- **Después de un outage de Meta/TikTok**: tus posts no se publicaron, quieres reintentar
- **Después de renovar un token**: operaciones que fallaron por token inválido ya pueden reintentar
- **Automático diario** (opcional en Railway cron): correr `/retry-failed --dry-run` para detectar pendientes
- **Antes de /dashboard**: verificar que no hay operaciones zombie contaminando métricas

---

## Qué considera "failed"

Operaciones que:
- Tienen lock en `.claude/state/locks/{key}.lock` (NO en `locks/completed/`)
- Status es `failure` o no tiene `completed_at`
- No han sido reintentadas más de 3 veces (campo `retry_count`)
- No tienen más de 24h de antigüedad (si más viejo, requerir `--force`)

---

## Precondiciones

1. `_core/load-brief` → abortar si no hay brief
2. `_core/preflight-check --domains anthropic,meta,telegram` + los dominios del dominio especificado

---

## Flujo

### Paso 1 — Interpretar argumentos

- `--domain` = scope: `publishing | community | ads | all` (default `all`)
- `--dry-run` = reporta qué reintentaría pero no ejecuta
- `--force` = ignora el límite de 24h de antigüedad

### Paso 2 — Escanear locks fallidos

```bash
# Buscar locks que no están en completed/ y tienen >1h (dar margen para que la operación original termine)
find .claude/state/locks -maxdepth 1 -name "*.lock" -mmin +60 ! -path "*/completed/*"
```

Para cada lock:
- Cargar su contenido
- Clasificar por `agent` del lock para enrutar al agente correcto
- Verificar `retry_count` (default 0 si no existe)

### Paso 3 — Agrupar por agente

```
Fallos agrupados:
  content-publisher: 2 locks
    - 2026-03-15 draft a1b2c3d4 (Instagram post)
    - 2026-03-16 draft e5f6g7h8 (Facebook post)
  paid-media: 1 lock
    - Campaign launch "leads-abril"
  community-manager: 0
```

### Paso 4 — Si --dry-run, reportar y salir

```
📋 OPERACIONES FALLIDAS DETECTADAS

Dominio: all
Encontradas: 3 locks sin completar

Por agente:
  📱 content-publisher:
    - 2026-03-15 draft a1b2c3d4 — error: "Instagram API timeout" (retry 1/3)
    - 2026-03-16 draft e5f6g7h8 — error: "token expired" (retry 0/3)
  📣 paid-media:
    - Campaign launch "leads-abril" — pending human action (not auto-retry)

Para reintentar ejecuta sin --dry-run.
```

### Paso 5 — Delegar al conductor para rescate real

```
Task(
  subagent_type: "conductor",
  description: "Retry failed operations",
  prompt: """
    Modo: retry-failed
    Domain filter: {domain}
    Force (ignore age limit): {force}

    Pipeline:
    1. Escanear locks fallidos según filtro
    2. Para cada uno:
       a. Incrementar retry_count
       b. Si retry_count >= 3: mover a locks/exhausted/ y notificar humano
       c. Si no: delegar al agente originador via Task con instrucción "retry draft {draft_id}"
       d. El agente debe idempotentemente verificar que la operación no se completó realmente
          (puede que el error haya sido en la respuesta, no en la operación — ej. publicó pero no leímos el ID)
    3. Agrupar resultados: cuántos se recuperaron, cuántos siguen fallando, cuántos se agotaron
  """
)
```

### Paso 6 — Presentar resultado

```
🔄 RETRY COMPLETADO

Procesados: 3 locks

✅ RECUPERADOS: 1
  - draft e5f6g7h8 — publicado en Instagram tras renovar token

🔁 RE-REINTENTABLES: 1
  - draft a1b2c3d4 — Instagram API sigue timeout, retry 2/3

⏸️ ESPERANDO HUMANO: 1
  - Campaign launch "leads-abril" — requiere acción manual en Ads Manager

❌ AGOTADOS (movidos a exhausted/): 0

➡️ SIGUIENTE PASO
  Reintentar en 1 hora: /retry-failed
  Dashboard: /dashboard
```

---

## Idempotencia

Los agentes al reintentar DEBEN:

1. Verificar si la operación real se completó (puede que el error haya sido solo en el response parsing):
   - Para posts: query a la plataforma por posts recientes del account para ver si el content ya está publicado
   - Para mensajes Telegram: query getUpdates para ver si el mensaje llegó
   - Para campañas: query ads account para ver si la campaña ya existe
2. Si la operación YA se completó → marcar lock como `completed` sin re-ejecutar
3. Si NO se completó → ejecutar normalmente

El skill `_core/state-store` tiene el método `acquire-lock` que incluye esta verificación.

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `--domain` | enum | `all` | `publishing` / `community` / `ads` / `all` |
| `--dry-run` | flag | false | Reporta sin ejecutar |
| `--force` | flag | false | Ignora límite de 24h antigüedad |

---

## Ejemplos de uso

```
/retry-failed                       # retry todo lo recuperable
/retry-failed --dry-run             # ver qué hay pendiente
/retry-failed --domain publishing   # solo posts fallidos
/retry-failed --force               # incluir locks de más de 24h
```

---

## Automatización recomendada

En Railway cron:
```
# Cada 2h, intenta recuperar operaciones recientes
0 */2 * * *   claude /retry-failed --dry-run

# Reporte nocturno de pending
0 23 * * *    claude /retry-failed --dry-run
```

Nunca correr `--force` en cron automático sin human-in-the-loop.

---

## Notas

- **No todas las operaciones son re-intentables**: lanzar una campaña de ads requiere acción humana en Ads Manager; esos locks se marcan como `requires_human_action`, no se reintenta automáticamente.
- **Posts fallidos**: si el fallo fue en API de la plataforma, el reintento es seguro. Si fue en nuestra generación/aprobación, revisar causa primero.
- **Si una operación agota 3 reintentos** → se mueve a `locks/exhausted/`. Humano debe decidir qué hacer.
- Toda la lógica interna está en `agents/conductor.md` modo retry-failed.
