---
name: load-brand-kit
description: Carga y valida brand-kit.json con fallback si no existe. Devuelve prompt injection snippets listos para inyectar en skills de generación de imagen y texto.
allowed-tools: [Read, Bash]
model: claude-haiku-4-5
---

# Skill: load-brand-kit

**Propósito**: Punto único de carga del `brand-kit.json`. Lo invocan todos los skills de generación visual y textual para inyectar identidad de marca consistente.

**Schema**: `skills/_core/schemas/brand-kit.schema.json`

---

## Cuándo invocar

- Al inicio de `generate-image-ai`, `generate-carousel`, `generate-reel`
- Al inicio de `generate-content`, `generate-tiktok-content`
- En agente `content-publisher` antes de generar cualquier post
- En agente `content-planner` antes de proponer tópicos

## Diferencia con load-brief

- `load-brief` → datos del negocio (quién, qué, para quién vende)
- `load-brand-kit` → identidad visual/verbal (cómo se ve y suena)

Ambos se cargan juntos. `load-brand-kit` es opcional (hay fallback); `load-brief` es obligatorio.

---

## Flujo

### Paso 1 — Localizar el archivo

Ruta esperada: `.claude/brand-kit.json`

### Paso 2 — Fallback si no existe

Si el archivo no existe, devolver un brand-kit mínimo generado desde `client-brief.json`:

```json
{
  "ok": true,
  "source": "fallback_from_brief",
  "brand_kit": {
    "version": "1.0",
    "brand_name": "{brief.company.name}",
    "confidence": "suggested",
    "sources": ["fallback — no brand-kit.json. Sugerir /brand-kit new"],
    "colors": {
      "primary": "#2C3E50",
      "secondary": "#E74C3C",
      "background": "#FFFFFF",
      "text_dark": "#2C3E50"
    },
    "typography": {
      "headings_font": "Inter",
      "body_font": "Inter"
    },
    "visual_identity": {
      "photography_style": "Fotografía editorial profesional, luz natural, composición limpia",
      "mood": "Profesional, confiable, accesible",
      "avoid": ["Fondos de stock photo genéricos", "Saturación excesiva"]
    },
    "content_voice": {
      "personality": "Profesional cercano, experto pero accesible",
      "tone_spectrum": "60% experto — 30% cercano — 10% inspiracional",
      "emoji_usage": "Moderado (1-3 por post)",
      "formatting_rules": ["Hook en primera línea", "Párrafos cortos"],
      "forbidden_words": ["el mejor", "únicos", "líderes"]
    },
    "prompt_injection": {
      "image_prefix": "Fotografía profesional de {brief.company.industry}. Luz natural, composición editorial limpia.",
      "image_suffix": "Mood: profesional y confiable. NO: stock photo genérico, saturación artificial.",
      "content_prefix": "Escribe para {brief.company.name}, con tono {brief.company.tone}.",
      "content_suffix": "Evitar superlativos vacíos. CTA en forma de pregunta."
    }
  },
  "warnings": ["Brand kit no definido. Ejecuta /brand-kit new para extraer identidad real."]
}
```

### Paso 3 — Si existe, leer y validar

Usar tool `Read`, parsear JSON. Validar campos obligatorios:

| Path | Obligatorio |
|---|---|
| `version` | `"1.0"` |
| `brand_name` | no vacío |
| `colors.primary` | hex válido |
| `colors.secondary` | hex válido |
| `colors.background` | hex válido |
| `colors.text_dark` | hex válido |
| `typography.headings_font` | no vacío |
| `typography.body_font` | no vacío |
| `visual_identity.photography_style` | no vacío |
| `visual_identity.mood` | no vacío |
| `visual_identity.avoid` | array ≥1 |
| `content_voice.personality` | no vacío |
| `content_voice.forbidden_words` | array (puede estar vacío) |
| `prompt_injection.image_prefix` | no vacío |
| `prompt_injection.image_suffix` | no vacío |
| `prompt_injection.content_prefix` | no vacío |
| `prompt_injection.content_suffix` | no vacío |

**Si falta algo**: completar con defaults del fallback y agregar warning.

### Paso 4 — Devolver objeto + injection snippets listos

```json
{
  "ok": true,
  "source": "brand-kit.json",
  "brand_kit": { /* objeto completo */ },
  "injection": {
    "image_prompt_wrapper": "{image_prefix}\n\n{USER_PROMPT}\n\n{image_suffix}\nEstilo: {visual_identity.photography_style}\nColores: {colors.primary}, {colors.secondary}\nEvitar: {visual_identity.avoid.join(', ')}",
    "content_system_prefix": "{content_prefix}\n\nPersonalidad: {content_voice.personality}\nTono: {content_voice.tone_spectrum}\nEmojis: {content_voice.emoji_usage}\nFormato:\n{content_voice.formatting_rules.join('\n- ')}\nProhibido: {content_voice.forbidden_words.join(', ')}\n\n{content_suffix}"
  },
  "warnings": []
}
```

El `injection.image_prompt_wrapper` y `injection.content_system_prefix` son strings listos para templating — el skill invocador solo tiene que reemplazar `{USER_PROMPT}` por su prompt propio.

---

## Uso típico en un skill de generación

```
1. Invocar _core/load-brief → contexto de cliente
2. Invocar _core/load-brand-kit → identidad visual/verbal
3. Construir prompt final:
   prompt_final = brand_kit.injection.content_system_prefix.replace('{USER_PROMPT}', prompt_del_skill)
4. Llamar al modelo con el prompt_final
```

---

## Notas

- Fallback es intencional: permite que el toolkit funcione el día 1 sin `/brand-kit new`.
- El fallback deriva nombre y tono del `client-brief.json`, no es completamente genérico.
- Si el brief tampoco existe, este skill falla con el mismo mensaje que `load-brief`.
