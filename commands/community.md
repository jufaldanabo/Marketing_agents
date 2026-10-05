---
description: Gestión conversacional de comentarios, DMs y menciones del cliente — con protocolo FAQ, SLA de respuesta y escalación de crisis. Phase 5 del flujo de agencia (comunidad).
argument-hint: [daily | crisis-only | faq-only] [--platforms ig,fb,tt] [--max N]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /community

**Propósito**: Procesar comentarios y mensajes pendientes de respuesta con la voz de marca definida, respetando SLA y escalando crisis cuando aplica.

**Agente invocado**: `community-manager` (vía Task tool)

**Fase del flujo de agencia**: **5 — Publicación, comunidad y pauta** (sub-fase comunidad)

---

## Cuándo ejecutar

- **Automático cada 4 horas** (Railway cron) — para respetar SLA típico de 24h
- Después de `/social-report` nocturno — si detectó alta prioridad
- On-demand cuando se detecta volumen alto de interacción (post viral)
- `crisis-only` cuando `social-monitor` emitió evento `crisis_detected`

---

## Precondiciones

1. `_core/load-brief` → necesita `brief.sales.response_sla_hours`, `brief.company.tone`
2. `_core/load-brand-kit` → necesita `content_voice.personality`, `forbidden_words`
3. `_core/preflight-check --domains meta,telegram`

---

## Flujo

### Paso 1 — Interpretar argumentos

- `$1` = modo: `daily | crisis-only | faq-only` (default `daily`)
- `--platforms` = filtro de plataformas (default: todas las activas)
- `--max N` = límite de items por corrida (default `20`)

### Paso 2 — Delegar al agente

```
Task(
  subagent_type: "community-manager",
  description: "Process pending community engagement",
  prompt: """
    Modo: {mode}
    Platforms: {platforms}
    Max items: {max}

    Pipeline esperado:
    1. Cargar reporte reciente de social-monitor o fetch nuevo si falta
    2. Dedup contra .claude/state/community/handled.json
    3. Match FAQ para respuestas estándar
    4. Generar respuestas con brand voice
    5. Clasificar escalation (auto_approved/needs_review/escalate_to_human)
    6. Batch approval vía telegram-approval (una sola interacción, no spam)
    7. Publicar aprobadas con idempotency locks
    8. Actualizar FAQ con respuestas útiles aprobadas sin edición
    9. Reportar resumen

    Si detecta crisis (comentario viral, acusación grave) emitir crisis_detected al conductor.
  """
)
```

### Paso 3 — Presentar resultado al usuario

```
💬 CICLO COMUNIDAD COMPLETADO — {FECHA} {HORA}

📊 PROCESADO
  Comentarios: {N} ({breakdown por prioridad})
  DMs: {M}
  Menciones: {K}

✅ RESPUESTAS PUBLICADAS: {X}
⚠️ PENDIENTES: {Y} ({razones})
🚨 ESCALADAS A HUMANO: {Z}

⏱️ SLA
  Objetivo: {brief.sales.response_sla_hours}h
  Tiempo promedio: {actual}h {🟢 OK | 🟡 cerca | 🔴 excedido}

📘 FAQ actualizado: {new_entries} nuevas respuestas aprendidas

➡️ Siguiente ciclo: {próximo cron automático}
```

Si hubo crisis detectada, se envía por Telegram priority=high automáticamente.

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | enum | `daily` | `daily` / `crisis-only` / `faq-only` |
| `--platforms` | lista | todas | `ig,fb,tt` |
| `--max` | int | 20 | Máximo items a procesar |

---

## Ejemplos de uso

```
/community                        # procesar todos pendientes
/community daily --max 10         # solo 10 items
/community crisis-only            # solo items marcados como críticos
/community faq-only               # solo responder los que matchean FAQ
```

---

## Notas

- **Nunca responde públicamente sin aprobación humana** — todo pasa por `_core/telegram-approval`
- Batch approval evita spamear al manager con 20 preguntas de aprobación
- FAQ learning: si una respuesta generada se aprueba sin edición → se sugiere agregarla al FAQ
- Toda la lógica interna está en `agents/community-manager.md`
- Para crisis: el agente emite evento, el `conductor` decide pausar publicación si aplica
