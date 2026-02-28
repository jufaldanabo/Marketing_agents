# Skill: handle-positive-response

**Propósito**: Gestiona la respuesta positiva de un lead al mensaje de primer contacto
o seguimiento. Actualiza el estado del lead, genera el mensaje de seguimiento
(confirmar interés + proponer envío de catálogo/propuesta), y notifica al vendedor.
**Modelo**: `claude-opus-4-6`
**Usado por**: `/followup-leads`

---

## Cuándo usar este skill

Cuando un lead que está en `status: "no_response"` o `status: "awaiting_response"`
responde con alguna señal de interés. Ejemplos de señales positivas:

- "Me interesa, ¿me puedes contar más?"
- "Sí, envíame información"
- "¿Cuáles son los precios?"
- "¿Tienen disponibilidad?"
- "¿Podrías enviarme un catálogo?"
- Cualquier pregunta sobre el producto o servicio

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `lead` | dict | Datos completos del lead desde `followup-tracking.json` |
| `response_text` | string | Lo que dijo el lead (transcripción o resumen) |
| `channel` | enum | Canal donde respondió: `linkedin` / `email` / `whatsapp` |
| `company_name` | string | Nombre de la empresa que vende |
| `product` | string | Producto o servicio ofrecido |
| `sender_name` | string | Nombre del vendedor |
| `sender_role` | string | Cargo del vendedor |
| `catalog_available` | bool | Si existe un catálogo o PDF para enviar |

## Paso 1 — Actualizar estado del lead

En el archivo `.claude/leads/followup-tracking.json`, actualizar el lead:

```json
{
  "status": "responded_positive",
  "responded_at": "{TIMESTAMP_ISO}",
  "response_channel": "{CHANNEL}",
  "response_summary": "{RESUMEN_DE_LO_QUE_DIJO}",
  "next_action": "send_catalog",
  "next_action_due": "{FECHA_DE_HOY}"
}
```

## Paso 2 — Clasificar la respuesta

Antes de generar el mensaje, clasificar qué tipo de respuesta positiva fue:

```
SYSTEM:
Clasifica esta respuesta de un prospecto de ventas B2B.

USER:
Respuesta del lead: "{RESPONSE_TEXT}"

Clasifica en una de estas categorías:
- "alta_intencion": pide precio, disponibilidad, quiere comprar pronto
- "intencion_media": pide información, quiere conocer más, abierto pero sin urgencia
- "baja_intencion": respuesta cordial pero vaga, "interesante", sin preguntas concretas

Devuelve JSON: {"intent": "alta_intencion|intencion_media|baja_intencion", "key_signal": "la frase clave que indica el interés"}
```

## Paso 3 — Generar mensaje de seguimiento

El mensaje debe:
- Agradecer la respuesta brevemente (1 frase)
- Confirmar que entendió el interés
- Proponer enviar catálogo/propuesta Y preguntar cómo prefieren recibirla
- NO mandar el catálogo aún — primero confirmar canal y pertinencia
- Mantener la conversación viva sin presionar

```
SYSTEM:
Eres un vendedor B2B experimentado. El lead respondió positivamente a tu mensaje
de prospección. Tu objetivo ahora es confirmar su interés, proponer enviar material
(catálogo o propuesta) y mantener el momentum sin presionar.

Reglas:
1. Mensaje corto — máximo 5-6 líneas en LinkedIn/WhatsApp, 8-10 en email
2. Agradecer sin exagerar ("gracias por responder" — no "qué alegría tan enorme")
3. Proponer el siguiente paso concreto: enviar catálogo + pedir confirmación del canal
4. Si la intención es ALTA: mencionar que puedes agendar una llamada rápida también
5. Si la intención es BAJA: no forzar — solo proponer enviar información sin compromiso
6. No mencionar precio aún — ese es el siguiente paso

USER:
Contexto del lead:
- Empresa: {LEAD.company_name}
- Contacto: {LEAD.contact.name}, {LEAD.contact.role}
- Señal de interés: {RESPONSE_TEXT}
- Clasificación: {INTENT}
- Canal actual: {CHANNEL}

Contexto de la empresa que vende:
- Empresa: {COMPANY_NAME}
- Producto: {PRODUCT}
- Vendedor: {SENDER_NAME}, {SENDER_ROLE}
- ¿Tiene catálogo?: {CATALOG_AVAILABLE}

Genera el mensaje de seguimiento y devuelve JSON:
{
  "channel": "{CHANNEL}",
  "subject": "asunto (solo si es email)",
  "message": "texto completo del mensaje",
  "next_step_proposed": "qué propones en el mensaje",
  "tone_used": "descripción del tono",
  "length_chars": 0,
  "urgency_applied": true/false
}
```

## Paso 4 — Preparar nota interna para el vendedor

Generar un resumen interno (no para enviar al lead) con contexto para la conversación:

```
SYSTEM:
Eres un asistente de ventas. Genera una nota de preparación breve para el vendedor
antes de continuar la conversación con este lead.

USER:
Lead: {LEAD.company_name} — {LEAD.contact.name}
Score original: {LEAD.score}/100
Por qué encaja: {LEAD.why_good_fit}
Lo que dijo: {RESPONSE_TEXT}
Clasificación de intención: {INTENT}
Historial de contactos: {LEAD.sequence_stage} seguimientos previos

Genera una nota de preparación con:
1. Resumen de quién es este lead (1-2 líneas)
2. Por qué respondió ahora (posible trigger)
3. Qué preguntan o quieren (basado en su respuesta)
4. Qué enviar: qué parte del catálogo/propuesta es más relevante para este perfil
5. Qué NO decir en la próxima interacción
6. Si intención es ALTA: sugerir agenda de llamada en las próximas 48h

Máximo 150 palabras. Tono de nota interna, no formal.
```

## Paso 5 — Notificar al vendedor por Telegram

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "🎯 LEAD RESPONDIÓ POSITIVAMENTE\n\n🏢 {LEAD.company_name}\n👤 {LEAD.contact.name} — {LEAD.contact.role}\n📱 Canal: {CHANNEL}\n\n💬 Dijo: \"{RESPONSE_TEXT}\"\n\n📊 Intención: {INTENT_EMOJI} {INTENT}\n\n📝 MENSAJE LISTO PARA ENVIAR:\n\n{MENSAJE_GENERADO}\n\n---\n🗒 NOTA INTERNA:\n{NOTA_DE_PREPARACION}\n\n✅ Actualizado en followup-tracking.json",
  "parse_mode": "Markdown"
}
```

**Emojis por intención:**
- `alta_intencion` → 🔥
- `intencion_media` → ⭐
- `baja_intencion` → 💡

## Output del skill

```json
{
  "lead_updated": true,
  "new_status": "responded_positive",
  "intent_classification": "intencion_media",
  "follow_up_message": {
    "channel": "whatsapp",
    "message": "Hola María, gracias por responder. Con gusto te cuento más sobre cómo trabajamos. ¿Te parece bien si te envío nuestro catálogo de telas recicladas? Te lo mando por WhatsApp o email, lo que prefieras.",
    "length_chars": 212
  },
  "prep_note": "Confecciones El Valle busca proveedores con certificación GOTS para nueva línea. Respondieron después del follow-up 1 (valor: dato de costos). Mostrar catálogo de telas certificadas. No mencionar precios aún. Potencial cierre rápido si el catálogo encaja.",
  "telegram_sent": true,
  "saved_to": ".claude/leads/followup-tracking.json"
}
```

## Integración con `/followup-leads`

Este skill se invoca desde `/followup-leads` cuando el usuario indica que un lead respondió.

**Flujo típico en `/followup-leads`:**

```
1. Usuario revisa la lista de leads
2. Ve que "Confecciones El Valle" respondió con interés
3. Selecciona ese lead y pega la respuesta del lead
4. handle-positive-response.md clasifica la respuesta, genera el mensaje y notifica
5. Usuario copia el mensaje generado y lo envía manualmente
6. followup-tracking.json queda actualizado
```

## Estados del lead después de este skill

| Acción siguiente | Status a usar |
|---|---|
| Envió el catálogo y espera respuesta | `catalog_sent` |
| Agendaron llamada | `meeting_scheduled` |
| Lead cerrado (compra) | `closed_won` |
| Lead perdió interés después del catálogo | `responded_negative` |
