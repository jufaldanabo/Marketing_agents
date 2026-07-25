# Skill: generate-trend-ideas

**Propósito**: Genera ideas de contenido concretas y ejecutables para la empresa,
inspiradas en los patrones virales identificados. Cada idea está adaptada al producto,
tono y cliente ideal de la empresa — no son ideas genéricas.
**Modelo**: `claude-sonnet-4-6` con `thinking: adaptive`
**Usado por**: `agents/trend-analyst-agent.md`, `commands/trend-ranking.md`

---

## Cuándo usar este skill

Usar después de `analyze-trend-content.md`. Recibe el análisis de patrones
y genera ideas específicas para la empresa, con nivel de detalle suficiente
para que el equipo pueda ejecutarlas sin más contexto.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `trend_analyses` | dict | Output completo de analyze-trend-content |
| `company_context` | dict | Contenido de `.claude/company-context.json` |
| `platform` | enum | `"youtube"` / `"tiktok"` / `"both"` |
| `ideas_per_video` | int | Ideas a generar por video analizado (default: 2) |

---

## Prompt de generación de ideas

```
SYSTEM:
Eres un estratega de contenido B2B para redes sociales especializado en el sector {INDUSTRY}.
Tu trabajo es traducir tendencias virales en ideas de contenido concretas y ejecutables
para {COMPANY_NAME}, adaptadas a su realidad, producto y cliente ideal.

REGLAS:
- NO generas ideas genéricas como "haz un video sobre tus productos"
- Cada idea menciona el ángulo específico para {COMPANY_NAME} y su producto
- Cada idea incluye el formato concreto (no "un video", sino "un video de 8-10 min
  con 3 planos: el proceso de entrada, la máquina en operación y el producto terminado")
- El gancho que propones (primeros 3 segundos o primera línea) es el texto exacto
  que diría el creador, adaptado al tono de la marca
- Las ideas consideran recursos de una PyME: teléfono, CapCut o similar,
  sin equipo de producción profesional obligatorio
- El cliente ideal ({INDUSTRY_TARGET}) debe reconocerse como destinatario de la idea

USER:
Genera {IDEAS_PER_VIDEO} ideas de contenido para {COMPANY_NAME} por cada tendencia
analizada, para la plataforma: {PLATFORM}.

EMPRESA: {COMPANY_NAME}
SECTOR: {INDUSTRY}
PRODUCTO/SERVICIO: {PRODUCT}
CLIENTE IDEAL: {INDUSTRY_TARGET} en {GEOGRAPHY}, tamaño {COMPANY_SIZE}
DECISOR DE COMPRA: {DECISION_MAKER_ROLE}
PROPUESTA DE VALOR: {VALUE_PROPOSITION}
TONO DE MARCA: {TONE}

TENDENCIAS ANALIZADAS:
{TREND_ANALYSES_JSON}

Para cada idea, devuelve este JSON exacto:
{
  "idea_id": "yt-1-a",
  "inspirado_en_url_o_id": "...",
  "patron_aplicado": "...",
  "plataforma": "youtube|tiktok",
  "titulo_sugerido": "Título concreto del video o post",
  "gancho": "Texto exacto de los primeros 3 segundos del video o primera línea del post",
  "formato": "Descripción concreta: duración, estructura, planos o secciones clave",
  "angulo": "Por qué este ángulo conecta con {DECISION_MAKER_ROLE} de {INDUSTRY_TARGET}",
  "llamada_a_accion": "CTA específico para B2B (ej: 'pide tu muestra', 'agenda una visita')",
  "dificultad_produccion": "baja|media|alta",
  "tiempo_estimado": "ej: 2h grabación + 1h edición en CapCut, sin equipo adicional"
}

Devuelve un array JSON de ideas. Ordena de menor a mayor dificultad de producción.
```

---

## Criterios de dificultad de producción

| Nivel | Criterios | Ejemplos |
|---|---|---|
| `baja` | Solo teléfono, sin edición compleja, en el lugar de trabajo habitual | Video de proceso en la planta filmado con teléfono, post de texto con foto |
| `media` | Requiere guión preparado, edición básica en CapCut, o involucra a clientes | Tutorial con subtítulos, testimonio de cliente grabado, comparativa visual |
| `alta` | Requiere producción planificada, locación especial, equipo adicional o múltiples tomas | Caso de éxito filmado en cliente, video con infografías, antes/después con producción |

---

## Output esperado

```json
[
  {
    "idea_id": "yt-1-a",
    "inspirado_en_url_o_id": "dQw4w9WgXcQ",
    "patron_aplicado": "revelacion_proceso_industrial",
    "plataforma": "youtube",
    "titulo_sugerido": "Así producimos 500 metros de tela en un turno — proceso completo en nuestra planta",
    "gancho": "¿Cuánto tarda hacer el rollo de tela que tu confección necesita? Te muestro todo el proceso en menos de 10 minutos.",
    "formato": "Video de 8-10 min. Estructura: pregunta retórica 0-15s → tour rápido de la planta 15-45s → proceso paso a paso con datos de tiempo y cantidad 45s-8min → CTA a pedir muestra.",
    "angulo": "Los jefes de producción de talleres quieren saber si el proveedor tiene capacidad real. Mostrar el proceso con cifras concretas (500m por turno, 3 máquinas, 2 operarios) genera confianza más que cualquier catálogo PDF.",
    "llamada_a_accion": "Al final: 'Pide tu muestra gratuita — link en la descripción o escríbenos por WhatsApp'",
    "dificultad_produccion": "baja",
    "tiempo_estimado": "2h grabación con teléfono en planta + 1h edición en CapCut"
  },
  {
    "idea_id": "yt-1-b",
    "inspirado_en_url_o_id": "dQw4w9WgXcQ",
    "patron_aplicado": "dato_sorprendente",
    "plataforma": "youtube",
    "titulo_sugerido": "El error que cometen el 70% de los talleres al elegir tela (y cómo evitarlo)",
    "gancho": "El 70% de los talleres de confección eligen la tela equivocada para sus productos. Este error les cuesta entre 15% y 30% más en rechazos y reprocesos.",
    "formato": "Video de 6-8 min. Estructura: dato impactante 0-20s → 3 errores comunes con ejemplos reales 20s-5min → cómo evitarlos con criterios técnicos 5-7min → CTA.",
    "angulo": "El decisor de compra (dueño del taller o jefa de producción) siente el dolor de los rechazos. Validar su experiencia con un dato les hace seguir viendo y comentar '¡a nosotros también nos pasó!'",
    "llamada_a_accion": "Descarga nuestra guía de especificaciones técnicas — link en descripción",
    "dificultad_produccion": "media",
    "tiempo_estimado": "3h preparación + 2h grabación + 2h edición con subtítulos"
  }
]
```

---

## Notas de implementación

- El `idea_id` se construye como `{plataforma}-{número_video}-{letra}`:
  `yt-1-a` = YouTube, video 1, idea A; `tt-2-b` = TikTok, video 2, idea B
- Priorizar siempre ideas de **baja dificultad** — la velocidad de implementación
  es clave para el equipo de marketing de una PyME
- Si `platform = "both"`, generar ideas tanto para YouTube (formato largo, tutorial)
  como para TikTok (formato corto, gancho directo, sin subtítulos obligatorios)
- Las ideas para TikTok deben asumir formato vertical, duración 30-90 segundos
  y gancho en los primeros 3 segundos
