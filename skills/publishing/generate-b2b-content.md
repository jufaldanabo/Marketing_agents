# Skill: generate-b2b-content

**Propósito**: Genera contenido B2B profesional para Instagram y/o Facebook usando Claude.
**Modelo**: `claude-opus-4-6`
**Usado por**: `publisher-agent.md`, `/publish-today`

---

## Cuándo usar este skill

Usar cuando necesites crear contenido de marketing B2B para redes sociales.
Es el bloque de generación de contenido del Agente Publicador.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `topic` | string | Tema del post | "beneficios telas recicladas" |
| `industry` | string | Sector industrial | "textil" |
| `company_name` | string | Nombre de empresa | "Textiles Andina" |
| `platform` | enum | Plataforma destino | "instagram" / "facebook" / "both" |
| `tone` | enum | Tono de comunicación | "professional" / "friendly" / "authoritative" |

## Prompt a ejecutar

```
SYSTEM:
Eres un experto en marketing B2B para redes sociales especializado en el sector {INDUSTRY}.
Generas contenido que conecta con tomadores de decisiones empresariales.
Adaptas el mensaje a las características de cada plataforma.
Devuelves ÚNICAMENTE JSON válido, sin texto adicional ni bloques de código.

USER:
Genera contenido B2B para redes sociales con estas especificaciones:

Empresa: {COMPANY_NAME}
Sector: {INDUSTRY}
Tema: {TOPIC}
Tono: {TONE}
Plataforma(s): {PLATFORM}

Especificaciones por plataforma:
- Instagram: visual y conciso, hook impactante en primer renglón, 5-10 hashtags relevantes,
  máx 2,200 caracteres, emojis con moderación
- Facebook: conversacional y detallado, 300-500 caracteres óptimos, máx 3 hashtags,
  incluir pregunta o call-to-action al final

El contenido debe:
1. Hablar directamente a decisores del sector {INDUSTRY}
2. Destacar valor de negocio, no solo características de producto
3. Ser auténtico y evitar clichés ("soluciones innovadoras", "líderes del mercado")
4. Incluir datos o insight específico del sector si es posible

Devuelve este JSON:
{
  "instagram": {
    "caption": "texto completo del post incluyendo emojis y hashtags",
    "hashtags": ["hashtag1", "hashtag2"],
    "hook": "primera línea del caption (el gancho)",
    "suggested_image": "descripción de la imagen ideal para este post"
  },
  "facebook": {
    "message": "texto del post para Facebook",
    "cta": "el call-to-action específico incluido",
    "suggested_image": "descripción de la imagen ideal para este post"
  },
  "meta": {
    "topic": "{TOPIC}",
    "generated_at": "{TIMESTAMP}",
    "word_count_ig": 0,
    "word_count_fb": 0
  }
}

Si platform es solo "instagram", omite la clave "facebook".
Si platform es solo "facebook", omite la clave "instagram".
```

## Output esperado

```json
{
  "instagram": {
    "caption": "¿Sabías que el 67% de los fabricantes de moda...",
    "hashtags": ["#textilsostenible", "#B2Btextil", "#moda"],
    "hook": "¿Sabías que el 67% de los fabricantes...",
    "suggested_image": "Rollo de tela reciclada con certificación GRS visible"
  },
  "facebook": {
    "message": "En Textiles Andina llevamos 3 años...",
    "cta": "¿Tu empresa ya está evaluando proveedores sostenibles?",
    "suggested_image": "Equipo de producción con muestras de tela reciclada"
  },
  "meta": {
    "topic": "beneficios telas recicladas",
    "generated_at": "2026-02-27T09:00:00",
    "word_count_ig": 187,
    "word_count_fb": 312
  }
}
```

## Variaciones de tono

| Tono | Características |
|---|---|
| `professional` | Formal, datos concretos, lenguaje técnico del sector |
| `friendly` | Cercano, primera persona, anécdotas, preguntas al lector |
| `authoritative` | Experto, tendencias, posicionamiento de pensamiento |
| `technical` | Especificaciones, procesos, métricas, certifications |

## Notas de implementación

- Usar streaming para respuestas largas: `client.messages.stream()`
- Si el JSON viene con bloques de código (```json), limpiarlos antes de parsear
- Validar que el caption de Instagram no supere 2,200 caracteres
- Si `word_count_ig` > 2200 chars, re-generar con instrucción de ser más conciso
