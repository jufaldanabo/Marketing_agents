---
name: generate-content
description: Generates marketing copy (caption, hashtags, hook, CTA) adapted per platform (Instagram, Facebook, TikTok, LinkedIn) AND adapted to brief.company.business_model (b2b/b2c/both). Returns strict JSON. Use when content-publisher needs the text portion of a post from a topic + pillar + format defined in the approved calendar.
allowed-tools: [Read, Write]
model: claude-opus-4-7
---

# Skill: generate-content

**Propósito**: Genera contenido profesional para redes sociales usando Claude, **adaptado dinámicamente al `business_model` del cliente** (B2B profesional / B2C conversacional / both híbrido).

**Usado por**: `publisher-agent.md`, `/publish-today`, agentes del toolkit que necesiten copy adaptado a marca.

**Antes se llamaba** `generate-b2b-content` — renombrado en v2.1 cuando el toolkit dejó de asumir B2B. La lógica se expandió para contemplar B2C y both.

---

## Cuándo usar este skill

Usar cuando el `content-publisher` o cualquier agente necesite:
- Caption + hashtags para Instagram
- Mensaje + CTA para Facebook
- Caption breve + hashtags virales para TikTok
- Thought-leadership long-form para LinkedIn (solo si business_model incluye B2B)

**El tono base lo determina `brief.company.business_model`**:
- `b2b` → profesional, educativo, orientado a decisión, data-driven
- `b2c` → conversacional, aspiracional, lifestyle, emocional
- `both` → mezcla según el `pillar` del post (educativo/casos → B2B; lifestyle/UGC → B2C)

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `topic` | string | Tema del post (de la parrilla) | "zapatos para la rutina diaria" |
| `pillar` | string | Pilar de contenido | "lifestyle" / "educativo" / "promocional" |
| `platform` | enum | Plataforma destino | "instagram" / "facebook" / "tiktok" / "linkedin" |
| `brief` | obj | Brief del cliente (vía `_core/load-brief`) | `{company, buyer_persona, business_model, tone, ...}` |
| `brand_kit` | obj | Brand kit (vía `_core/load-brand-kit`) | `{content_voice, prompt_injection, ...}` |

## Prompt a ejecutar

**El prompt se construye dinámicamente según `brief.company.business_model`**:

```
SYSTEM:
Eres un experto en marketing para redes sociales del sector {brief.company.industry}.
{IF business_model == "b2b":}
Generas contenido profesional que conecta con tomadores de decisión en empresas —
educativo, data-driven, orientado a resolver problemas de negocio. Tono: autoritario pero accesible.
{IF business_model == "b2c":}
Generas contenido conversacional, aspiracional y emocional que conecta con el consumidor final
en su día a día. Priorizas narrativa, lifestyle y experiencia por encima de specs técnicas.
{IF business_model == "both":}
Adaptas el tono según el pilar: profesional/educativo para pilares B2B (casos, datos, thought-leadership),
conversacional/lifestyle para pilares B2C (UGC, inspiracional, entretenimiento). El pilar de este post
es "{pillar}" → ajusta tono acorde.

Siempre aplicas la voz definida en {brand_kit.content_voice.personality} y respetas
{brand_kit.content_voice.forbidden_words}.
Devuelves ÚNICAMENTE JSON válido, sin texto adicional ni bloques de código.

USER:
Genera contenido para redes sociales con estas especificaciones:

Empresa: {brief.company.name}
Business model: {brief.company.business_model}
Sector: {brief.company.industry}
Buyer persona objetivo: {brief.buyer_persona.name} ({brief.buyer_persona.age_range}, {brief.buyer_persona.role or "consumidor final"})
  Dolores: {brief.buyer_persona.pain_points}
  Formatos que consume: {brief.buyer_persona.format_preferences}
Tema: {topic}
Pilar: {pillar}
Tono base: {brief.company.tone}
Plataforma(s): {platform}

Prompt injection del brand kit:
PREFIX: {brand_kit.prompt_injection.content_prefix}
SUFFIX: {brand_kit.prompt_injection.content_suffix}

Especificaciones por plataforma:
- Instagram: visual y conciso, hook impactante en primer renglón, 5-10 hashtags relevantes,
  máx 2,200 caracteres, emojis según {brand_kit.content_voice.emoji_usage}
- Facebook: conversacional y detallado, 300-500 caracteres óptimos, máx 3 hashtags,
  incluir pregunta o CTA al final
- TikTok: breve (1-3 líneas de caption), hashtags virales + nicho, hook en primera palabra
- LinkedIn (solo si business_model incluye B2B): long-form 1200-2500 chars, estructura
  pregunta-insight-data-cta, sin emojis excesivos

El contenido debe:
1. **Hablar al buyer_persona concreto** (nombre, edad, rol, dolores), no a un público genérico
2. **Respetar el business_model**: si B2C, nada de "optimice su proceso"; si B2B, nada de "vívelo"
3. Destacar el valor conectado al pain_point relevante del buyer_persona
4. Ser auténtico y evitar clichés y palabras prohibidas del brand kit
5. Incluir datos o insight específico cuando sea posible

Devuelve este JSON (solo los campos de las plataformas solicitadas):
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
  "tiktok": {
    "caption": "caption breve con hashtags",
    "hook": "primera palabra o frase impactante",
    "hashtags": ["#tag1", "#tag2"]
  },
  "linkedin": {
    "post": "long-form 1200-2500 chars",
    "hook": "pregunta o dato de apertura",
    "cta": "qué quieres que haga el lector"
  },
  "meta": {
    "topic": "{topic}",
    "pillar": "{pillar}",
    "business_model_adapted": "{brief.company.business_model}",
    "generated_at": "{TIMESTAMP}",
    "word_count_by_platform": {}
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
