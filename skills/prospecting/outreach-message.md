# Skill: outreach-message

**Propósito**: Genera mensajes de primer contacto personalizados para cada prospecto.
**Modelo**: `claude-opus-4-6`
**Usado por**: `prospecting-agent.md`, `/prospect-leads`

---

## Cuándo usar este skill

Usar después de `qualify-leads.md` para generar el mensaje de primer contacto
(LinkedIn, email o WhatsApp) personalizado para cada hot/warm lead.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `lead` | dict | Datos del lead calificado |
| `product` | string | Producto/servicio que se ofrece |
| `company_name` | string | Nombre de la empresa que contacta |
| `sender_name` | string | Nombre de quien envía el mensaje |
| `sender_role` | string | Cargo de quien envía |
| `channel` | enum | `linkedin` / `email` / `whatsapp` |
| `value_proposition` | string | Propuesta de valor principal |

## Principios del mensaje de primer contacto B2B

**Lo que DEBE tener:**
1. **Personalización real** — mencionar algo específico de la empresa del prospecto
2. **Relevancia inmediata** — conectar su situación con el producto en 1 línea
3. **Brevedad** — máximo 5 líneas en LinkedIn / 8 en email
4. **Una sola pregunta** — no pedir reunión + demo + llamada al mismo tiempo
5. **Tono humano** — no parecer un template masivo (aunque lo sea)

**Lo que NO debe tener:**
- "Espero que este mensaje te encuentre bien"
- "Somos líderes en el mercado con más de X años"
- Múltiples call-to-action en el mismo mensaje
- Adjuntos en el primer contacto
- Precio o propuesta completa en el primer mensaje

## Plantillas base por canal

### LinkedIn — Mensaje directo (máx 300 caracteres)
```
Hola {NOMBRE}, vi que {EMPRESA} {TRIGGER_EVENT o DETALLE_ESPECÍFICO}.

En {MI_EMPRESA} trabajamos con fabricantes de {SECTOR} que buscan {BENEFICIO_CLAVE}.

¿Tiene sentido conversar 15 min esta semana?
```

### LinkedIn — Nota de conexión (máx 300 caracteres)
```
Hola {NOMBRE}, trabajo con empresas de {SECTOR} en {GEOGRAFÍA} que buscan {BENEFICIO}.
Creo que podría ser relevante para {EMPRESA}. ¿Conectamos?
```

### Email — Asunto + cuerpo (máx 8 líneas)
```
Asunto: {TEMA_RELEVANTE_PARA_ELLOS} — {MI_EMPRESA}

Hola {NOMBRE},

{OBSERVACIÓN_ESPECÍFICA_SOBRE_SU_EMPRESA_O_CONTEXTO}.

En {MI_EMPRESA} ayudamos a {TIPO_EMPRESA} a {BENEFICIO_PRINCIPAL},
específicamente {DETALLE_QUE_LES_APLICA}.

¿Tendría 20 minutos esta semana o la próxima para explorar si tiene sentido?

{NOMBRE_REMITENTE}
{CARGO} | {MI_EMPRESA}
{TELÉFONO}
```

### WhatsApp (solo si hay contexto previo o referido)
```
Hola {NOMBRE}, soy {NOMBRE_REMITENTE} de {MI_EMPRESA}.

{CONEXIÓN_O_REFERIDO}: "{FRASE_BREVE}".

Le escribo porque {RAZÓN_ESPECÍFICA_Y_PERSONALIZADA}.

¿Le parece bien si le comparto algo breve sobre esto?
```

## Prompt de generación para Claude

```
SYSTEM:
Eres un especialista en ventas B2B consultivas. Escribes mensajes de primer contacto
que se leen como escritos por una persona real, no como templates masivos.
Eres directo, relevante y respetuoso del tiempo del prospecto.
Nunca escribes más de lo necesario. La personalización debe ser genuina.

USER:
Genera un mensaje de primer contacto para este prospecto:

EMPRESA QUE CONTACTA:
- Nombre: {COMPANY_NAME}
- Producto/servicio: {PRODUCT}
- Propuesta de valor: {VALUE_PROPOSITION}
- Remitente: {SENDER_NAME}, {SENDER_ROLE}

PROSPECTO:
- Empresa: {LEAD.company_name}
- País: {LEAD.country} | Ciudad: {LEAD.city}
- Sector: {LEAD.industry}
- Contacto: {LEAD.contact.name}, {LEAD.contact.role}
- Por qué encaja: {LEAD.why_good_fit}
- Señal/trigger: {LEAD.trigger_event}
- Score: {LEAD.score}/100

CANAL: {CHANNEL}

Genera el mensaje para {CHANNEL} usando los principios B2B:
1. Personaliza con algo específico de {LEAD.company_name} o su contexto
2. Conecta su situación con {PRODUCT} en máx 1-2 líneas
3. Una sola llamada a la acción: pedir conversar (no demo, no propuesta)
4. Tono: {TONE} pero humano y directo

Devuelve JSON:
{
  "channel": "{CHANNEL}",
  "subject": "asunto del email (solo si es email)",
  "message": "texto completo del mensaje",
  "personalization_hook": "el detalle específico que usaste para personalizar",
  "cta": "el call-to-action específico",
  "length_chars": 0,
  "tone_check": "profesional | cercano | formal"
}

También genera 2 variantes alternativas del mismo mensaje con enfoques distintos.
```

## Estrategia de seguimiento (follow-up)

Si no hay respuesta, el agente puede generar mensajes de seguimiento:

| Seguimiento | Cuándo | Enfoque |
|---|---|---|
| Follow-up 1 | 5-7 días después | Aportar valor (artículo, dato del sector) |
| Follow-up 2 | 10 días después | Cambio de ángulo (otro beneficio) |
| Follow-up 3 | 14 días después | Cierre suave ("¿No es el momento adecuado?") |
| Break-up | 21 días después | Dejar la puerta abierta y cerrar el ciclo |

## Output esperado

```markdown
## MENSAJES DE PRIMER CONTACTO GENERADOS
Lead: Confecciones El Valle S.A.S. — María González
Canal: LinkedIn
Score del lead: 88/100

### VERSIÓN PRINCIPAL
**Personalización usada**: "Vi que publicaron buscando proveedor con certificación GOTS"

Hola María, vi que Confecciones El Valle está buscando proveedor de materiales
con certificación GOTS para su nueva línea sostenible.

En Textiles Andina trabajamos con fabricantes de ropa en Colombia que necesitan
exactamente eso — telas recicladas certificadas con entrega en 15 días.

¿Tiene 15 minutos esta semana para explorar si encajamos?

---
### VARIANTE A
[...]

### VARIANTE B
[...]

📋 Copiar mensaje listo para LinkedIn/Email
💾 Guardado en: .claude/leads/2026-02-27/outreach-valle.md
```

## Consideraciones éticas

- Nunca fabricar información sobre la empresa prospecto
- No usar datos personales obtenidos de fuentes no públicas
- Respetar las preferencias de contacto (si alguien dice "no contactar", registrarlo)
- No enviar mensajes masivos sin personalización real
- Cumplir con regulaciones de privacidad (GDPR, habeas data Colombia, etc.)
