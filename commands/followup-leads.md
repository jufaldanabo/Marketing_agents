---
description: Genera y envía mensajes de seguimiento a leads sin respuesta.
argument-hint: [lead_id]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /followup-leads

**Propósito**: Reactivar leads que no respondieron al primer contacto con una secuencia de seguimiento multi-toque.
**Agente invocado**: `sales-prospector` (modo `followup`, vía Task tool)
**Fase del flujo de agencia**: Auxiliar B2B (prospección y pipeline)

---

## Precondiciones

1. Ejecutar `_core/load-brief` → si falta `.claude/client-brief.json` o `brief.b2b_sales.enabled != true`, abortar con mensaje:
   `⚠️ Este cliente no tiene prospección B2B activada. Edita brief.b2b_sales.enabled.`
2. Ejecutar `_core/preflight-check --domains anthropic,telegram` → abortar si alguno es crítico (sin API key o sin bot).
3. Verificar que exista `.claude/leads/followup-tracking.json`. Si no existe pero hay reportes previos en `.claude/leads/YYYY-MM-DD/leads-report.json`, inicializarlo con todos los leads conocidos en estado `no_response`.

---

## Flujo

### Paso 1 — Parsear argumentos

| Argumento | Significado |
|---|---|
| (vacío) | Procesar **todos** los leads con acción pendiente hoy |
| `$1 = lead_id` | Solo seguimiento del lead específico (ej. `confecciones-el-valle`) |
| `$1 = --urgent` | Solo leads Hot con 7+ días sin respuesta |
| `$1 = --stage N` | Solo leads cuya próxima etapa calculada = N |

### Paso 2 — Delegar al agente vía Task

Invocar `sales-prospector` con el modo `followup`:

```
Task tool:
  subagent_type: "sales-prospector"
  prompt: |
    MODO: followup
    SCOPE: {all | lead_id={X} | urgent | stage={N}}
    TRACKING_FILE: .claude/leads/followup-tracking.json
    LEADS_DIR: .claude/leads/

    Para cada lead con status="no_response":
      1. Calcular días desde last_contact_date
      2. Determinar sequence_stage (1=5-8d, 2=10-13d, 3=16-20d, 4=22+d break-up)
      3. Leer outreach original en .claude/leads/*/outreach-{slug}.md
      4. Generar mensaje con skill follow-up-sequence
      5. Devolver bloque estructurado por lead:
         - lead_id, company_name, contact, channel, stage, days
         - mensaje principal + variante A
         - ángulo y mejor momento de envío

    Al terminar, devolver un resumen JSON con:
      { "leads_processed": N, "messages_generated": N, "pending_file_updates": [...] }
```

### Paso 3 — Presentar resultado al usuario

Mostrar cada mensaje generado con el bloque de acciones:

```
═══════════════════════════════════════
🔥 {EMPRESA} — Etapa {N}/4
Contacto: {NOMBRE} | {CANAL} | {DIAS}d sin respuesta
Ángulo: {ANGULO}
Enviar: {MEJOR_MOMENTO}

MENSAJE PRINCIPAL:
{TEXTO}

VARIANTE A:
{TEXTO_ALT}

[P] Publicar principal  [A] Variante A
[E] Editar  [S] Solo guardar  [X] Saltar
═══════════════════════════════════════
```

Según selección:
- **S / P / A** → guardar en `.claude/leads/{HOY}/followup-{slug}-stage{N}.md`
- **P / A** → copiar al portapapeles (LinkedIn/WhatsApp no tienen envío directo) con instrucciones de envío manual; si canal=email y hay SMTP configurado, enviar.
- Actualizar `followup-tracking.json`: `last_contact_date`, `sequence_stage`, `status=awaiting_response`.

Resumen final:

```
## RESUMEN /followup-leads — {FECHA}
✅ Mensajes generados: {N}
📋 Copiados para envío manual: {N}
💾 Solo guardados: {N}

PRÓXIMOS SEGUIMIENTOS:
• {FECHA}: {EMPRESA} — Etapa {N}
```

---

## Argumentos

```bash
/followup-leads                      # Todos los leads con acción hoy
/followup-leads confecciones-valle   # Solo ese lead
/followup-leads --urgent             # Solo Hot con 7+ días
/followup-leads --stage 2            # Solo etapa 2
```

## Ejemplo

```
/followup-leads --urgent
→ sales-prospector (modo followup, scope=urgent)
→ 3 mensajes generados para 3 Hot leads
→ Usuario aprueba 2, salta 1
→ tracking.json actualizado
```

## Notas

- Estados válidos en `followup-tracking.json`: `no_response`, `awaiting_response`, `responded_positive`, `responded_negative`, `not_right_time`, `disqualified`, `closed_won`.
- Si un lead llega a etapa 4 sin respuesta, se marca como break-up y pasa a `disqualified` tras 7 días sin respuesta al break-up.
- Para integrar con `/prospect-leads`: ejecutar lunes (follow-up) y jueves (nuevos leads) para mantener el pipeline balanceado.
- Toda la lógica real vive en el agente `sales-prospector` — este command solo orquesta el modo `followup`.
