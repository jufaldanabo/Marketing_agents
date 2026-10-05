---
name: generate-carousel
description: Generates a full Instagram carousel (3-10 slides) with narrative structure, per-slide copy, text overlays and AI-generated images. Delegates image generation to generate-image-ai (never calls fal.ai directly).
allowed-tools: [Read, Write, Bash]
model: claude-opus-4-7
---

# Skill: generate-carousel

> **DELEGAR a `generate-image-ai`**: Este skill NO debe llamar a fal.ai directamente.
> La generación de cada imagen de slide se delega al skill `generate-image-ai`, que
> encapsula la lógica de prompt conversacional, img2img con fotos de referencia,
> seguridad y guardado de artefactos. Este skill solo construye el `topic`, `category`,
> `platform` y descripción por slide, y recibe de vuelta la `image_url` pública.


**Propósito**: Genera un carousel completo (3-10 slides) con imagen y texto por slide,
manteniendo coherencia visual y narrativa. Cada slide se genera con IA.
**Herramientas**: fal.ai (generación de imágenes por slide)
**Usado por**: `/publish-today` cuando `artifact_type == "carousel"`

---

## Cuándo usar este skill

Cuando la parrilla indica `artifact_type: "carousel"` o el agente decide que el tema
se beneficia de un formato multi-slide (educativo, paso a paso, listas, comparativas).

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `topic` | string | Tema del carousel |
| `content_pillar` | string | Pilar de contenido (educativo, informativo, etc.) |
| `company_name` | string | Nombre de la empresa |
| `industry` | string | Sector |
| `brief` | string | Descripción del contenido (de la parrilla, o generado) |
| `brand_kit` | object | Brand kit completo (colores, tipografía, estilo visual) |

### Inputs opcionales

| Input | Tipo | Default |
|---|---|---|
| `slide_count` | int | 7 (recomendado: 5-8 para engagement óptimo) |
| `platform` | string | "instagram" |
| `hook` | string | Se genera si no viene |
| `visual_direction` | string | Del brand kit si no viene |

---

## Arquitectura del carousel

Un carousel efectivo tiene esta estructura narrativa:

```
Slide 1 — HOOK (portada)
  → La más importante. Detiene el scroll.
  → Imagen impactante + texto grande y claro (5-8 palabras máx)
  → Debe generar curiosidad o prometer valor

Slides 2-N — CONTENIDO (desarrollo)
  → Una idea por slide (nunca más)
  → Texto legible sin zoom (mínimo 24pt equivalente)
  → Visual consistente con slide 1 (misma paleta, tipografía)
  → Cada slide tiene sentido sola pero invita a seguir

Slide final — CTA (cierre)
  → Llamada a la acción clara
  → Puede incluir: guardar, compartir, seguir, comentar
  → Color de fondo diferente (accent color del brand kit)
```

---

## Proceso de generación

### Paso 1 — Diseñar la narrativa del carousel

```
SYSTEM:
Eres un diseñador de contenido para redes sociales especializado en carousels
de alto engagement para {INDUSTRY}. Dominas el storytelling visual.
{BRAND_KIT.prompt_injection.content_prefix}

USER:
Diseña la estructura narrativa de un carousel sobre:

Tema: {TOPIC}
Pilar: {CONTENT_PILLAR}
Empresa: {COMPANY_NAME}
Sector: {INDUSTRY}
Brief: {BRIEF}
Número de slides: {SLIDE_COUNT}

Personalidad de marca: {BRAND_KIT.content_voice.personality}
Frases firma: {BRAND_KIT.content_voice.signature_phrases}
Palabras prohibidas: {BRAND_KIT.content_voice.forbidden_words}

Para cada slide define:
1. Texto principal (máximo 15 palabras — se lee en móvil sin zoom)
2. Texto secundario (máximo 25 palabras — opcional, subtítulo o dato de apoyo)
3. Tipo visual (foto de producto, infografía, texto sobre fondo, dato estadístico)
4. Descripción de la imagen de fondo

REGLAS:
- Slide 1 = HOOK: pregunta provocadora, dato impactante, o afirmación atrevida
- Cada slide siguiente resuelve o desarrolla lo planteado en slide 1
- Último slide = CTA con fondo de color primario ({BRAND_KIT.colors.primary})
- Consistencia visual: misma ubicación del texto, misma paleta, mismo estilo
- Texto siempre legible: alto contraste con el fondo
- No repetir la misma estructura visual en slides consecutivos

Devuelve JSON:
{
  "carousel_title": "título interno del carousel",
  "narrative_type": "lista|paso_a_paso|problema_solucion|datos|storytelling|comparativa",
  "slides": [
    {
      "number": 1,
      "role": "hook",
      "text_primary": "Texto grande del slide",
      "text_secondary": "Subtítulo o dato de apoyo (o null)",
      "visual_type": "foto_producto|infografia|texto_fondo|dato|behind_scenes",
      "image_description": "Descripción detallada de la imagen de fondo",
      "background_color": "#hex o null si es foto",
      "text_color": "#hex para el texto principal",
      "text_position": "center|top|bottom"
    }
  ],
  "caption": "Caption completo para Instagram (incluye hashtags al final)",
  "hashtags": ["#hash1", "#hash2"],
  "cta_text": "Call to action del último slide"
}
```

### Paso 2 — Generar imagen de cada slide

Para cada slide, construir el prompt de imagen incorporando el brand kit:

```
{BRAND_KIT.prompt_injection.image_prefix}

Slide {N} de carousel para {INDUSTRY}.
{slide.image_description}

Estilo: {BRAND_KIT.visual_identity.photography_style}
Composición: {BRAND_KIT.visual_identity.composition}

IMPORTANTE para carousel:
- Dejar espacio para texto superpuesto en la zona: {slide.text_position}
- Si text_position es "center", la imagen debe tener zona central despejada o degradado
- Si text_position es "bottom", tercio inferior debe ser simple/oscuro
- Colores dominantes: {BRAND_KIT.colors.primary}, {BRAND_KIT.colors.secondary}
- Formato cuadrado (1:1) para Instagram, 1080x1080px
- Evitar elementos que compitan con el texto superpuesto

{BRAND_KIT.prompt_injection.image_suffix}
```

**Delegar a `generate-image-ai` para cada slide** (no llamar a fal.ai directamente):

Invocar el skill `generate-image-ai` una vez por slide con:
- `topic`: el `text_primary` del slide (resumido si es largo)
- `category`: `content_pillar` del carousel
- `company_name`, `industry`: inputs del carousel
- `platform`: "instagram" (fuerza 1:1 `square_hd`)
- `brand_style`: `brand_kit` del input
- `product_slug`: opcional, el detectado por `generate-image-ai` desde el topic
- Descripción visual del slide: pasada como contexto adicional del prompt

El skill `generate-image-ai` se encarga de: elegir modo text-to-image vs edit-image,
construir el prompt conversacional en español, llamar a `fal-ai/nano-banana-2` o
`fal-ai/nano-banana-2/edit`, validar la imagen y guardar el artefacto. Devuelve
`image_url` pública lista para Instagram Graph API.

Si `generate-image-ai` falla por falta de `FAL_KEY`, propagar el error — este
skill no debe fabricar un fallback de prompt manual silencioso.

### Paso 3 — Componer el resultado

```json
{
  "artifact_type": "carousel",
  "topic": "{TOPIC}",
  "slide_count": 7,
  "narrative_type": "lista",
  "slides": [
    {
      "number": 1,
      "role": "hook",
      "text_primary": "¿Sabías que el 80% del pan que comes NO es artesanal?",
      "text_secondary": null,
      "visual_type": "foto_producto",
      "image_url": "https://fal.media/files/xxx/slide1.jpeg",
      "image_prompt": "Close-up de masa madre burbujeante...",
      "background_color": null,
      "text_color": "#FFFFFF",
      "text_position": "center"
    },
    {
      "number": 2,
      "role": "content",
      "text_primary": "1. La masa madre necesita 24 horas de fermentación",
      "text_secondary": "El pan industrial solo fermenta 45 minutos",
      "visual_type": "foto_producto",
      "image_url": "https://fal.media/files/xxx/slide2.jpeg",
      "image_prompt": "Bowl de masa madre con burbujas...",
      "background_color": null,
      "text_color": "#FFFFFF",
      "text_position": "bottom"
    }
  ],
  "caption": "¿Sabías que el 80% del pan que consumes NO es artesanal?\n\nDesliza para descubrir las 5 diferencias...\n\n#PanArtesanal #Inside",
  "hashtags": ["#PanArtesanal", "#MasaMadre", "#Inside"],
  "instagram_publish_data": {
    "type": "CAROUSEL",
    "children": [
      {"image_url": "https://fal.media/...", "is_carousel_item": true},
      {"image_url": "https://fal.media/...", "is_carousel_item": true}
    ],
    "caption": "..."
  }
}
```

---

## Publicación en Instagram (Graph API)

Los carousels en Instagram requieren un flujo de 3 pasos:

### 1. Crear cada slide como "hijo"
```
POST https://graph.facebook.com/v21.0/{IG_ACCOUNT_ID}/media
  image_url={SLIDE_IMAGE_URL}
  is_carousel_item=true
  access_token={TOKEN}
```
Repetir para cada slide. Guardar cada `creation_id`.

### 2. Crear el contenedor carousel
```
POST https://graph.facebook.com/v21.0/{IG_ACCOUNT_ID}/media
  media_type=CAROUSEL
  children={CREATION_ID_1},{CREATION_ID_2},{CREATION_ID_3}
  caption={CAPTION}
  access_token={TOKEN}
```

### 3. Publicar
```
POST https://graph.facebook.com/v21.0/{IG_ACCOUNT_ID}/media_publish
  creation_id={CAROUSEL_CREATION_ID}
  access_token={TOKEN}
```

---

## Tipos de carousel por pilar

| Pilar | Estructura recomendada | Slides | Ejemplo |
|---|---|---|---|
| Educativo | paso_a_paso o lista | 7-8 | "5 tipos de masa madre que debes conocer" |
| Informativo | datos o comparativa | 5-6 | "Pan artesanal vs industrial: los números" |
| Entretenimiento | storytelling | 5-7 | "Un día en Inside: de 4am al primer cliente" |
| Inspiracional | storytelling | 5-6 | "De un horno casero a 3 locales en 2 años" |
| Promocional | problema_solucion | 4-5 | "¿Buscas pan sin conservantes? Nosotros lo hacemos" |
| Interactivo | lista con pregunta | 6-7 | "¿Cuántos de estos panes has probado? (Swipe)" |

---

## Reglas de diseño visual

1. **Consistencia**: Todos los slides deben parecer del mismo "set" — misma paleta, misma fuente, mismo estilo de imagen
2. **Legibilidad**: Texto debe leerse en pantalla de celular sin hacer zoom (mínimo 24pt equivalente)
3. **Contraste**: Si la imagen es clara → texto oscuro. Si es oscura → texto blanco. Usar sombra o degradado si es necesario
4. **Espacio**: Nunca llenar más del 40% del slide con texto
5. **Navegación**: Poner indicador sutil de "desliza" o flecha en slide 1
6. **Ratio**: 1:1 (cuadrado) para Instagram feed. 4:5 para más espacio vertical
7. **CTA slide**: Fondo sólido del color primario de marca, texto en blanco, una sola acción clara

---

## Notas de implementación

- Generar las imágenes en paralelo cuando sea posible (todas son independientes)
- Si falla la generación de un slide, no detener — marcar como fallido y continuar
- El caption de Instagram va SOLO en el contenedor carousel, no en cada slide
- Máximo 10 slides por carousel (límite de Instagram)
- Mínimo 2 slides (o no es carousel)
- Si FAL_KEY no está disponible, generar solo los prompts para uso en Canva/Midjourney
