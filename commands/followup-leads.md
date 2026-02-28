# Command: /followup-leads

**Propósito**: Genera mensajes de seguimiento para leads que no respondieron al primer contacto.
**Modelo**: `claude-opus-4-6`
**Skills usados**: `follow-up-sequence.md`, `qualify-leads.md`

---

## Cuándo usar este command

Usar cuando han pasado 5+ días desde el primer mensaje a un lead y no hay respuesta.
Ideal ejecutarlo 1-2 veces por semana para mantener el pipeline activo.

```bash
/followup-leads           # Revisa todos los leads activos y genera seguimientos
/followup-leads urgent    # Solo leads Hot que llevan 7+ días sin respuesta
/followup-leads {EMPRESA} # Seguimiento específico para una empresa
/followup-leads stage 2   # Solo genera seguimientos de etapa 2
```

## Flujo de ejecución

### Paso 1 — Leer leads activos

Leer archivos de leads guardados en `.claude/leads/`:

```
.claude/leads/
├── 2026-02-20/
│   ├── leads-report.json          ← lista de leads calificados
│   └── outreach-*.md              ← mensajes de primer contacto
├── 2026-02-24/
│   └── leads-report.json
└── followup-tracking.json         ← historial de seguimientos
```

**Estructura de followup-tracking.json:**
```json
{
  "leads": [
    {
      "company_name": "Confecciones El Valle",
      "contact": "María González",
      "channel": "linkedin",
      "score": 88,
      "category": "hot",
      "first_contact_date": "2026-02-20",
      "last_contact_date": "2026-02-20",
      "sequence_stage": 1,
      "status": "no_response",
      "notes": ""
    }
  ]
}
```

Si `followup-tracking.json` no existe, crearlo con todos los leads del reporte más reciente.

### Paso 2 — Identificar qué leads necesitan seguimiento

Para cada lead con `status = "no_response"`, calcular días desde `last_contact_date`:

| Días sin respuesta | Etapa recomendada |
|---|---|
| 5-8 días | Seguimiento 1 |
| 10-13 días | Seguimiento 2 |
| 16-20 días | Seguimiento 3 |
| 22+ días | Break-up |
| Respondió positivo | ✅ Mover a CRM / siguiente paso |
| Respondió negativo | ❌ Marcar como "no interesado por ahora" |

Filtrar solo los leads que requieren acción hoy.
Ordenar por: prioridad (hot > warm) y días sin respuesta (mayor primero).

### Paso 3 — Mostrar leads pendientes

Presentar resumen antes de generar mensajes:

```
## LEADS QUE REQUIEREN SEGUIMIENTO HOY
Fecha: 2026-02-27 | Leads activos: {N_TOTAL} | Con acción pendiente: {N_ACCIÓN}

🔥 HOT LEADS ({N})
• Confecciones El Valle — María González (Etapa 2 — 11 días sin respuesta) [LinkedIn]
• Textiles Bogotá — Carlos Ruiz (Break-up — 23 días) [Email]

✅ WARM LEADS ({N})
• ModaExport S.A. — Ana Torres (Etapa 1 — 6 días) [LinkedIn]

¿Generar mensajes para todos? (S/N) o especifica cuáles:
```

### Paso 4 — Generar mensajes de seguimiento

Para cada lead seleccionado, invocar skill `follow-up-sequence.md` con:
- `lead` — datos del lead
- `original_outreach` — primer mensaje enviado (leer de `.claude/leads/*/outreach-{empresa}.md`)
- `channel` — canal del lead
- `days_since_last_contact` — calculado en paso 2
- `sequence_stage` — etapa calculada en paso 2
- `company_name`, `product`, `value_proposition` — de CLAUDE.md

### Paso 5 — Presentar mensajes generados

Para cada lead mostrar:

```
═══════════════════════════════════════
🔥 CONFECCIONES EL VALLE — Etapa 2/4
Contacto: María González | LinkedIn | 11 días sin respuesta

MENSAJE PRINCIPAL:
Hola María, sé que estás ocupada — te escribo muy brevemente.

[...texto completo del mensaje...]

Ángulo: Certificación GOTS como diferenciador competitivo
Enviar: Martes o miércoles, 9-11am

VARIANTE A:
[...variante alternativa...]

─────────────────────────────────────
Acciones:
[P] Publicar principal  [A] Publicar variante A
[E] Editar antes de enviar  [S] Solo guardar  [X] Saltar este lead
═══════════════════════════════════════
```

### Paso 6 — Enviar o guardar mensajes

Según la selección del usuario para cada lead:

**Solo guardar (opción S):**
- Guardar en `.claude/leads/{FECHA}/followup-{empresa}-stage{N}.md`
- Copiar al portapapeles para envío manual

**Enviar (requiere integración con canal):**

Para LinkedIn y WhatsApp, Claude Code **no puede enviar directamente** (no hay API pública para envío automático). En su lugar:

```
📋 INSTRUCCIONES PARA ENVIAR EN LINKEDIN:
1. Abrir: linkedin.com/messaging
2. Buscar: {NOMBRE} en {EMPRESA}
3. Copiar el siguiente mensaje:

"{MENSAJE_COMPLETO}"

✅ Una vez enviado, marca como "enviado" aquí para actualizar el tracking.
```

Para **email** (si hay configuración SMTP):
```
Enviar email a {EMAIL_CONTACTO}
Asunto: {SUBJECT}
Cuerpo: {MESSAGE}
```

### Paso 7 — Actualizar tracking

Actualizar `followup-tracking.json` con:
```json
{
  "company_name": "Confecciones El Valle",
  "last_contact_date": "2026-02-27",
  "sequence_stage": 2,
  "last_message_sent": "seguimiento-2-gots",
  "status": "awaiting_response"
}
```

Resumen final:

```
## RESUMEN /followup-leads
Fecha: 2026-02-27

✅ Mensajes generados: {N}
📋 Copiados para envío manual: {N}
💾 Solo guardados: {N}
🔄 Tracking actualizado: {N} leads

PRÓXIMOS SEGUIMIENTOS:
• 2026-03-03: Confecciones El Valle — Etapa 3
• 2026-03-05: ModaExport — Etapa 2
• 2026-03-10: Textiles Bogotá — Break-up

💾 Guardado en: .claude/leads/followup-tracking.json
```

## Variables de entorno requeridas

```env
COMPANY_NAME=...
INDUSTRY=...
PRODUCT=...
VALUE_PROPOSITION=...
SENDER_NAME=...
SENDER_ROLE=...
```

## Manejo de estados de leads

Los leads pueden tener los siguientes estados en `followup-tracking.json`:

| Status | Descripción | Acción |
|---|---|---|
| `no_response` | Sin respuesta desde el último mensaje | Generar siguiente etapa |
| `awaiting_response` | Mensaje enviado hoy, esperando | No hacer nada |
| `responded_positive` | Respondió con interés | Mover a siguiente paso del proceso comercial |
| `responded_negative` | No interesado | Archivar, marcar para contacto en 6 meses |
| `not_right_time` | Respondió al break-up que sí pero más adelante | Contactar en fecha indicada |
| `disqualified` | No es un lead válido | Remover del pipeline |
| `closed_won` | Se convirtió en cliente | Celebrar 🎉 |

## Integración con /prospect-leads

```
/prospect-leads   →  genera leads nuevos + mensajes iniciales
/followup-leads   →  da seguimiento a leads ya contactados
```

Usar ambos commands semanalmente para mantener el pipeline activo:
- Lunes: `/followup-leads` — revisar respuestas de la semana anterior
- Jueves: `/prospect-leads` — agregar nuevos leads al pipeline
