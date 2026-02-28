# Skill: follow-up-sequence

**Propósito**: Genera secuencias de seguimiento multi-toque para leads que no respondieron al primer contacto.
**Modelo**: `claude-opus-4-6`
**Usado por**: `prospecting-agent.md`, `/followup-leads`

---

## Por qué este skill es crítico

El 80% de las ventas B2B requieren 5+ contactos antes de cerrar.
La mayoría de vendedores se rinden después del primer mensaje sin respuesta.
Este skill genera los mensajes 2, 3 y 4 — cada uno con un ángulo diferente
para mantener relevancia sin volverse molesto.

## Cuándo usar este skill

Usar después de `outreach-message.md` cuando un lead **no respondió** en:
- LinkedIn: 5-7 días desde el mensaje inicial
- Email: 5 días desde el envío
- WhatsApp: 4 días (canal más informal)

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `lead` | dict | Datos del lead calificado (de qualify-leads) |
| `original_outreach` | dict | El primer mensaje enviado y su fecha |
| `channel` | enum | `linkedin` / `email` / `whatsapp` |
| `days_since_last_contact` | int | Días desde el último mensaje |
| `company_name` | string | Empresa que hace el seguimiento |
| `product` | string | Producto/servicio ofrecido |
| `value_proposition` | string | Propuesta de valor principal |
| `sequence_stage` | int | En qué seguimiento estamos: 1, 2, 3 o 4 (break-up) |

## Lógica de la secuencia

| Etapa | Cuándo enviar | Objetivo | Enfoque |
|---|---|---|---|
| Seguimiento 1 | 5-7 días después del primer contacto | Recordatorio suave | Agregar valor (dato, artículo, insight del sector) |
| Seguimiento 2 | 10-12 días después | Cambiar ángulo | Mostrar un beneficio diferente al del primer mensaje |
| Seguimiento 3 | 16-18 días después | Crear urgencia suave | Mencionar contexto de mercado o timing relevante |
| Break-up | 22-25 días después | Cerrar el ciclo | Dejar la puerta abierta, dar opción de "no por ahora" |

## Principios de seguimiento B2B

**Cada mensaje debe:**
1. Ser más corto que el anterior (no repetir todo lo del primero)
2. Agregar algo nuevo — dato, perspectiva, recurso, pregunta
3. Referirse brevemente al mensaje anterior sin sonar desesperado
4. Tener una sola acción pedida (no múltiples opciones)
5. Mantener el mismo canal (no cambiar de LinkedIn a email sin razón)

**Lo que NUNCA debe hacer:**
- "Solo quería hacer seguimiento a mi mensaje anterior"
- Reenviar el mismo mensaje
- Mencionar cuántos mensajes llevas enviando
- Sonar impaciente o molesto
- Pedir disculpas por escribir

## Valor agregado por etapa

### Seguimiento 1 — Agregar valor
```
Opciones para agregar valor:
- Dato del sector relevante para ellos: "Vi que el precio del algodón subió 8% este mes..."
- Artículo o recurso útil: "Publicaron este estudio sobre certificaciones GOTS..."
- Caso de éxito anónimo: "Una empresa similar a la suya logró reducir costos un 15%..."
- Pregunta abierta que no presione: "¿Están evaluando nuevos proveedores este trimestre?"
```

### Seguimiento 2 — Cambio de ángulo
```
Si el primer mensaje fue sobre: precio/costo → ahora hablar de: tiempo de entrega / calidad
Si el primer mensaje fue sobre: calidad → ahora hablar de: sostenibilidad / certificaciones
Si el primer mensaje fue sobre: sostenibilidad → ahora hablar de: eficiencia operacional
```

### Seguimiento 3 — Urgencia contextual
```
Fuentes de urgencia genuina (no fabricada):
- Temporada alta se acerca: "Con el pico de demanda de [mes] en 6 semanas..."
- Cambio en el mercado: "Con los nuevos aranceles que entran en [mes]..."
- Capacidad limitada: "Tenemos disponibilidad para 2-3 clientes nuevos este trimestre..."
- Evento del sector: "Antes de la feria de [nombre] sería ideal coordinar..."
```

### Break-up — Cierre elegante
```
El objetivo es:
1. Aceptar que quizás no es el momento
2. No quemarse el puente
3. Dejar una puerta abierta clara
4. Hacer sentir bien al prospecto (no culpable)
```

## Prompt de generación para Claude

```
SYSTEM:
Eres un especialista en ventas B2B consultivas con expertise en seguimiento de prospectos.
Escribes mensajes de seguimiento que se leen como de una persona real, no como plantillas automatizadas.
Entiendes que el prospecto está ocupado — respetas su tiempo y lo valoras.
Cada mensaje aporta algo nuevo y relevante.

USER:
Genera el mensaje de seguimiento etapa {SEQUENCE_STAGE} para este lead:

EMPRESA QUE CONTACTA:
- Nombre: {COMPANY_NAME}
- Producto/servicio: {PRODUCT}
- Propuesta de valor: {VALUE_PROPOSITION}

PROSPECTO:
- Empresa: {LEAD.company_name}
- Contacto: {LEAD.contact.name}, {LEAD.contact.role}
- Sector: {LEAD.industry}
- Por qué encaja: {LEAD.why_good_fit}
- Score: {LEAD.score}/100

HISTORIAL DE CONTACTO:
- Primer mensaje enviado: {ORIGINAL_OUTREACH.date}
- Primer mensaje (resumen): {ORIGINAL_OUTREACH.message[:200]}
- Canal: {CHANNEL}
- Días sin respuesta: {DAYS_SINCE_LAST_CONTACT}

ETAPA {SEQUENCE_STAGE} DE SEGUIMIENTO:
{
  1: "Seguimiento suave — agrega valor con dato/recurso del sector",
  2: "Cambio de ángulo — muestra un beneficio diferente al del primer mensaje",
  3: "Urgencia contextual — menciona timing o contexto de mercado relevante",
  4: "Break-up — cierra el ciclo elegantemente, deja puerta abierta"
}[SEQUENCE_STAGE]

Reglas para este mensaje:
1. Máximo {MAX_LENGTH} caracteres (LinkedIn: 300, email: 600, WhatsApp: 250)
2. No repetir el primer mensaje
3. Una sola pregunta o llamada a la acción
4. Tono: cercano pero profesional
5. Si es etapa 4 (break-up), no pedir nada — solo cerrar bien

Devuelve JSON:
{
  "stage": {SEQUENCE_STAGE},
  "channel": "{CHANNEL}",
  "subject": "asunto del email (solo si es email, null para otros canales)",
  "message": "texto completo del mensaje",
  "value_added": "qué dato/recurso/perspectiva nueva incluiste",
  "angle": "desde qué ángulo abordaste esta vez",
  "length_chars": 0,
  "send_recommendation": {
    "best_day": "martes | miércoles | jueves",
    "best_time": "9-11am | 2-4pm",
    "reason": "por qué este momento"
  }
}

También genera una variante alternativa del mensaje con diferente apertura.
```

## Plantillas base por etapa y canal

### LinkedIn — Seguimiento 1 (valor)
```
{NOMBRE}, vi que {DATO_RELEVANTE_DEL_SECTOR}.

Pensé en ustedes en {EMPRESA} porque {CONEXIÓN_CON_SU_SITUACIÓN}.

¿Están evaluando esto en su hoja de ruta este año?
```

### LinkedIn — Seguimiento 2 (ángulo diferente)
```
{NOMBRE}, sé que estás ocupado — te escribo brevemente.

Además de {BENEFICIO_1_DEL_PRIMER_MENSAJE}, muchos de nuestros
clientes en {SECTOR} valoran {BENEFICIO_2_DIFERENTE}.

¿Esto es relevante para {EMPRESA} ahora mismo?
```

### LinkedIn — Seguimiento 3 (urgencia)
```
{NOMBRE}, {CONTEXTO_DE_MERCADO_REAL}.

Para empresas como {EMPRESA}, el timing importa aquí.
Tenemos disponibilidad para {N} clientes nuevos este trimestre.

¿Vale la pena una llamada corta antes de {FECHA_REFERENCIA}?
```

### LinkedIn — Break-up
```
{NOMBRE}, asumo que el timing no es el adecuado — lo entiendo perfectamente.

Si en algún momento evalúan {PRODUCTO}, encantado de retomar la conversación.
Le deseo éxito a {EMPRESA} con sus proyectos. 🤝
```

### Email — Seguimiento 1 (valor)
```
Asunto: {TEMA_RELEVANTE_PARA_ELLOS} | {DATO_O_RECURSO}

Hola {NOMBRE},

{DATO_O_INSIGHT_DEL_SECTOR_EN_1-2_LÍNEAS}.

Lo menciono porque {CONEXIÓN_DIRECTA_CON_SU_SITUACIÓN}.

En {MI_EMPRESA} estamos viendo esto con varios clientes en {SECTOR}.
¿Sería de utilidad conversar 15 minutos?

{FIRMA}
```

### Email — Break-up
```
Asunto: Cerrando el ciclo — {MI_EMPRESA}

Hola {NOMBRE},

He intentado contactarte algunas veces sin suerte — entiendo que
los tiempos no cuadran o simplemente no es una prioridad ahora.

No hay problema. Si en algún momento {EMPRESA} evalúa {PRODUCTO},
aquí estaré.

¡Mucho éxito con sus proyectos!

{FIRMA}
P.D. Si prefieres que no te escriba más, solo respóndeme y lo respeto. 🙏
```

## Output esperado

```markdown
## SECUENCIA DE SEGUIMIENTO GENERADA
Lead: Confecciones El Valle S.A.S. — María González
Canal: LinkedIn | Etapa: 2 de 4
Días sin respuesta: 11

### VERSIÓN PRINCIPAL
**Ángulo usado**: Certificación GOTS como diferenciador competitivo (cambio desde entrega rápida)
**Valor agregado**: Tendencia del mercado de moda sostenible en Colombia

Hola María, sé que estás ocupada — te escribo muy brevemente.

Además de los tiempos de entrega, muchos fabricantes con los que trabajamos
en Colombia valoran que nuestras telas recicladas llevan certificación GOTS —
lo que les abre puertas en exportaciones a Europa y marcas como H&M o Zara.

¿Es esto relevante para la estrategia actual de El Valle?

---
### VARIANTE A
[...]

📅 Mejor momento para enviar: Martes o miércoles, 9-11am
💾 Guardado en: .claude/leads/2026-02-27/followup-valle-stage2.md
```

## Métricas a trackear

Guardar en `.claude/leads/{FECHA}/followup-metrics.json`:
- Tasa de respuesta por etapa (etapa 1 vs 2 vs 3)
- Canal más efectivo para respuestas
- Tiempo promedio hasta primera respuesta
- Porcentaje de leads que responden al break-up (señal de interés futuro)
