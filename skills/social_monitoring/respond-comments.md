# Skill: respond-comments

**Propósito**: Genera respuestas apropiadas y personalizadas a comentarios en Instagram y Facebook.
**Modelo**: `claude-sonnet-4-6`
**Usado por**: `monitoring-agent.md`, `/respond-comments`

---

## Por qué este skill cierra el ciclo

El skill `send-telegram.md` notifica sobre comentarios pendientes.
Este skill genera las respuestas — cerrando el loop: detectar → analizar → responder.
Responder en las primeras 2 horas aumenta el alcance orgánico en ~40%.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `comments` | list | Lista de comentarios del reporte nocturno |
| `company_name` | string | Nombre de la empresa |
| `industry` | string | Sector industrial |
| `brand_voice` | string | Descripción del tono de marca |
| `platform` | enum | `instagram` / `facebook` |
| `post_context` | string | De qué trataba el post que recibió los comentarios |

## Clasificación de comentarios y estrategia de respuesta

### Tipo 1 — Consulta comercial (intención de compra)
```
Señales: preguntan precio, disponibilidad, cómo comprar, tiempos de entrega
Prioridad: URGENTE — responder en menos de 1 hora
Estrategia: Agradecer, responder brevemente, mover a canal privado (DM o WhatsApp)
Tono: cálido y profesional, nunca revelar precios en comentario público
```

### Tipo 2 — Pregunta técnica o de producto
```
Señales: preguntan especificaciones, certificaciones, proceso, materiales
Prioridad: ALTA — responder en 2-4 horas
Estrategia: Respuesta concisa con el dato clave + invitar a DM para detalles
Tono: experto y accesible, demostrar conocimiento sin abrumar
```

### Tipo 3 — Comentario positivo / elogio
```
Señales: "Excelente", "Me encanta", "Así se hace", emojis positivos
Prioridad: MEDIA — responder en 24 horas
Estrategia: Agradecer con calidez, personalizar la respuesta, no ser genérico
Tono: genuino y agradecido, evitar "¡Gracias por tu comentario!"
```

### Tipo 4 — Comentario negativo / queja
```
Señales: Insatisfacción, problema con producto/servicio, crítica pública
Prioridad: URGENTE — responder en menos de 1 hora
Estrategia: Empatía primero, mover conversación a privado SIEMPRE
Tono: tranquilo, no defensivo, orientado a solución
NUNCA: argumentar en público, borrar el comentario (excepto ofensas graves), ignorar
```

### Tipo 5 — Spam / irrelevante
```
Señales: publicidad de terceros, contenido sin relación, bots
Prioridad: BAJA — solo si no hay comentarios más importantes
Estrategia: No responder o respuesta mínima educada
Acción sugerida: Ocultar o reportar según caso
```

## Prompt de generación para Claude

```
SYSTEM:
Eres el community manager B2B de {COMPANY_NAME}, empresa del sector {INDUSTRY}.
Escribes respuestas que suenan humanas y auténticas, nunca como templates corporativos.
Conoces el negocio y puedes hablar con autoridad sobre el sector.
Cada respuesta está personalizada al comentario específico — nunca copias y pegas.

Voz de marca: {BRAND_VOICE}

Reglas de oro:
1. Nunca empezar con "¡Hola! Gracias por tu comentario"
2. Nunca publicar precios en comentarios públicos
3. Siempre mover quejas a privado (DM o email)
4. Máximo 3-4 líneas por respuesta en comentario público
5. Usar el nombre del usuario si está disponible

USER:
Genera respuestas para estos comentarios en {PLATFORM}:

POST QUE RECIBIÓ LOS COMENTARIOS:
"{POST_CONTEXT}"

EMPRESA: {COMPANY_NAME} | SECTOR: {INDUSTRY}

COMENTARIOS A RESPONDER:
{LISTA_DE_COMENTARIOS}

Para cada comentario, devuelve:
{
  "comment_id": "...",
  "username": "@usuario",
  "original_comment": "texto del comentario",
  "comment_type": "consulta_comercial | pregunta_tecnica | positivo | negativo | spam",
  "priority": "urgente | alta | media | baja",
  "public_response": "respuesta para publicar en el comentario (máx 4 líneas)",
  "private_followup": "mensaje sugerido para DM si aplica (null si no aplica)",
  "action": "responder | ocultar | reportar | escalar_a_humano",
  "escalation_reason": "por qué necesita revisión humana (null si no aplica)",
  "response_rationale": "en 1 línea, por qué elegiste ese enfoque"
}
```

## Plantillas de respuesta por tipo (para personalizar)

### Consulta comercial
```
¡Buena pregunta, {NOMBRE}! Nuestras {PRODUCTO} están disponibles en {CONDICIÓN_GENERAL}.
Para darte detalles específicos y precios según tu volumen, te escribo por DM 📩
```

### Pregunta técnica
```
{NOMBRE}, {DATO_TÉCNICO_CLAVE_EN_1_LÍNEA}. Para el detalle completo de especificaciones,
te compartimos nuestra ficha técnica por DM — ¿te parece?
```

### Comentario positivo (personalizado)
```
{DETALLE_QUE_MUESTRA_QUE_LEÍSTE_EL_COMENTARIO}, {NOMBRE} 🙌
{FRASE_QUE_AGREGA_VALOR_O_DATO_RELACIONADO}
```

### Comentario negativo
```
{NOMBRE}, entendemos tu situación y queremos resolverla.
¿Nos escribes por DM con los detalles? Nos comprometemos a revisarlo hoy.
```

### Crisis / comentario muy negativo con audiencia
```
{NOMBRE}, lamentamos que hayas tenido esa experiencia — no es lo que queremos para nuestros clientes.
Te escribimos por DM para atenderte directamente y encontrar una solución. 🙏
```

## Señales de escalación a humano

El agente debe marcar para revisión humana cuando:
- El comentario menciona problemas legales, accidentes o daños graves
- El usuario tiene muchos seguidores (posible influencer o periodista)
- La queja lleva más de un comentario de seguimiento público
- Hay lenguaje agresivo u ofensivo que podría requerir bloqueo
- El tema es sensible (precios, comparación con competencia, etc.)

## Output esperado

```markdown
## RESPUESTAS GENERADAS
Post: "Beneficios de las telas recicladas para fabricantes de moda"
Plataforma: Instagram | Comentarios procesados: 5

### 🚨 URGENTE — @maria_compras
Comentario: "¿Tienen tela reciclada con certificación GOTS? ¿Cuánto sale el metro?"
Tipo: Consulta comercial
Respuesta pública:
  "¡Hola María! Sí trabajamos con telas recicladas certificadas GOTS en varias
  gramaturas. Los precios varían según volumen y especificación — te escribo
  por DM ahora mismo con la info 📩"
DM sugerido:
  "Hola María, acabo de verte en el post. Para telas recicladas GOTS tenemos
  desde 180 gsm hasta 320 gsm. ¿Qué volumen necesitas aproximadamente y para
  qué tipo de prenda? Así te doy un precio exacto."
Acción: Responder comentario + enviar DM

---
### ✅ ALTA — @textiles_bogota
[...]
```

## Métricas de respuesta a trackear

Guardar en `.claude/responses/{FECHA}.json`:
- Tiempo promedio de respuesta
- Comentarios respondidos vs total
- Distribución por tipo (comercial, técnico, positivo, negativo)
- Comentarios escalados a humano
- Leads generados desde comentarios (conversión a DM)
