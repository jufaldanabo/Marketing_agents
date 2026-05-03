# Skill: generate-image-prompt

**Propósito**: Genera un prompt conversacional con contexto de negocio para herramientas
de imagen IA: `fal-ai/nano-banana-2`, Midjourney, DALL-E 3, Adobe Firefly o Stable Diffusion.
Es el paso de construcción de prompt que usa `generate-image-ai.md` internamente,
y también se puede usar de forma independiente para generación manual.
**Modelo**: `claude-sonnet-4-6`
**Usado por**: `generate-image-ai.md`, `publisher-agent.md`, `/publish-today`

---

## Por qué este skill es crítico

Instagram requiere imagen para publicar en feed. Sin imagen, el Agente Publicador
solo puede publicar en Facebook. Este skill genera el prompt necesario para crear la imagen,
ya sea de forma automática (via `generate-image-ai`) o manualmente con Midjourney/DALL-E/Firefly.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `mode` | enum | **Modo de generación** | `text-to-image` / `edit-image` |
| `topic` | string | Tema del post | "tendencias de embalaje sostenible" |
| `company_name` | string | Nombre de la empresa | "Botas García" |
| `industry` | string | Sector industrial | "calzado" |
| `product_description` | string | Descripción visual del producto extraída de foto de referencia (opcional) | "botas de cuero negro con suela gruesa y hebillas laterales" |
| `brand_style` | string | Estilo visual de la marca (opcional) | "colores tierra, minimalista" |
| `special_date` | string | Fecha especial (opcional) | "Día de la Mujer" |
| `tool` | enum | Herramienta destino | `fal-ai` / `midjourney` / `dalle` / `firefly` / `stable-diffusion` / `generic` |
| `format` | enum | Formato de la imagen | `square` (1:1) / `portrait` (4:5) / `landscape` (16:9) |

### Cuándo usar cada modo

| Modo | Cuándo | Qué hace |
|---|---|---|
| `text-to-image` | No hay foto de referencia, o se quiere una imagen completamente nueva | Genera un prompt que describe la escena completa desde cero |
| `edit-image` | Hay foto de referencia y se quiere modificar/ambientar la foto existente | Genera una instrucción de edición sobre qué cambiar en la imagen |

## Especificaciones por plataforma

| Plataforma | Formato recomendado | Resolución mínima |
|---|---|---|
| Instagram Feed | 1:1 (cuadrado) o 4:5 (portrait) | 1080×1080 px |
| Instagram Stories | 9:16 (vertical) | 1080×1920 px |
| Facebook Feed | 1:1 o 16:9 | 1200×630 px |
| LinkedIn | 1.91:1 | 1200×627 px |

---

## Modo A — Prompt para Text-to-Image

> Usar cuando `mode == "text-to-image"`.
> Genera un prompt que describe la escena completa desde cero.

> **Principio clave:** Los modelos modernos (nano-banana-2, FLUX, DALL-E 3) responden mejor
> a lenguaje conversacional con contexto de negocio que a descripciones técnicas de fotografía.
> El prompt debe sonar como si el dueño de la empresa le pidiera la imagen a un diseñador.

**Plantilla base:**

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}.
Necesito crear una imagen para publicar en redes sociales.

{Si hay PRODUCT_DESCRIPTION → agregar: Mi producto es {PRODUCT_DESCRIPTION}.}
La temática del post de hoy es: {TOPIC}.
{Si hay SPECIAL_DATE → agregar: La ocasión especial es: {SPECIAL_DATE}.}
{Si hay brand_style → agregar: El estilo visual de mi marca es: {BRAND_STYLE}.}

{Si hay PRODUCT_DESCRIPTION:
  Crea una imagen atractiva y creativa para redes sociales que muestre mi producto
  en un contexto relacionado con la temática. La imagen debe verse real y profesional,
  sin texto ni logos superpuestos.
}
{Si NO hay PRODUCT_DESCRIPTION:
  Crea una imagen atractiva y creativa para redes sociales que represente esta temática
  en el contexto de {INDUSTRY}. La imagen debe verse real y profesional,
  sin texto ni logos superpuestos.
}
```

**Adaptar la instrucción final según el tópico:**

| Tipo de tópico | Agregar al final |
|---|---|
| Tip del sector | "Muéstralo en un ambiente de trabajo o producción, con elementos propios del sector." |
| Caso de éxito / cliente satisfecho | "Contexto profesional, ambiente de éxito y confianza." |
| Detrás de escena / proceso | "Ambiente de producción o taller, contexto de trabajo real." |
| Tendencia / mercado | "Estilo editorial moderno, composición limpia y contemporánea." |
| Fecha especial | "La imagen debe evocar {SPECIAL_DATE}, con ambientación acorde." |
| Nuevo lanzamiento | "Presentación destacada del tema, protagonismo total, fondo limpio." |

---

## Modo B — Prompt para Edit Image

> Usar cuando `mode == "edit-image"`.
> Toma una foto casual/real del producto y la transforma en una imagen profesional
> lista para publicar en Instagram, redes sociales y página web.

> **Principio clave:** El prompt es conversacional, como si el dueño de la empresa
> le pidiera a un diseñador que mejore su foto. Incluye: quién soy, qué es el producto,
> qué quiero que cambie, y cómo debe verse el resultado final. Este enfoque produce
> resultados superiores a instrucciones técnicas cortas.

### Reglas críticas para edit-image

Estas reglas determinan si el resultado es realista o artificial:

| Regla | Correcto | Incorrecto |
|---|---|---|
| **Anclar el sujeto** | "Keep the main subject from the original photo" | "Keep the core visual elements" (vago, el modelo reinterpreta) |
| **Solo cambiar el entorno** | "enhance it with [elementos alrededor]" | "Show the fabric being cut" (describe acción → transforma el producto) |
| **No describir acciones** | "professional cutting tools nearby" | "Show cutting at a 45-degree angle" (el modelo cambia el producto) |
| **Nombrar la empresa** | "for Sesgo Express, a textile company in Medellín" | "for textile bias tape marketing" (genérico, el modelo improvisa) |
| **Estilo fotográfico concreto** | "Commercial photography style, warm industrial lighting, sharp focus" | "Professional lighting suitable for B2B marketing" (vago) |
| **Enriquecer, no reemplazar** | "enhance it with colorful rolls, tools, clean workshop" | "transform it into a professional studio photo" (el modelo recrea todo) |

> **Resumen:** Nunca le digas al modelo qué HACER con el producto. Solo dile qué PONER ALREDEDOR.
> El producto se queda exactamente como está en la foto original.

### Cadena de pensamiento para construir el prompt

Antes de escribir el prompt, pensar en estos 5 pasos:

1. **¿Quién soy?** — Nombre de la empresa, sector, ubicación. Ser específico.
2. **¿Qué se ve en la foto?** — Usar la `technical_description` del producto aprobada
   en `/init`. Si no existe, describir lo que se observa en la imagen.
3. **¿Qué quiero que cambie del ENTORNO?** — Limpiar el fondo, remover objetos, mejorar la superficie.
   La foto original suele ser casual (escritorio desordenado, piso, fondo de bodega).
   **NUNCA describir una acción para el producto** (no "show cutting", no "show being used").
   Solo describir qué elementos agregar ALREDEDOR: herramientas, decoración, superficie, fondo.
4. **¿Cómo debe verse el resultado?** — Estilo fotográfico concreto: tipo de iluminación
   (cálida industrial, suave natural, lateral dramática), enfoque (sharp focus, shallow depth),
   atmósfera (clean workshop, elegant studio, minimalist).
5. **¿Para qué plataforma?** — Instagram, redes sociales, página web.
   Siempre: sin texto superpuesto, sin logos, sin watermarks.

### Plantilla base

```
Professional B2B social media photo for {COMPANY_NAME}, a {INDUSTRY} company
{Si hay LOCATION → agregar: in {LOCATION}}.

Keep the main subject from the original photo but enhance it with
{ELEMENTOS_DEL_ENTORNO}.

{INSTRUCCIONES_DE_EDICIÓN}

The main subject is {ELEMENTO_PROTAGONISTA_DEL_PRODUCTO}. Remove everything
around it that is not part of the product.

{CONTEXTO_DEL_TÓPICO_DEL_DÍA}

{ESTILO_FOTOGRÁFICO}.
```

**Notas sobre el idioma:** El prompt se escribe en **inglés** porque los modelos de imagen
(nano-banana-2, FLUX, DALL-E) fueron entrenados predominantemente en inglés y producen
mejores resultados. El resto del skill (instrucciones a Claude) sigue en español.

**Construir `{ELEMENTOS_DEL_ENTORNO}`:** Listar 2-4 elementos concretos que van
ALREDEDOR del producto (no sobre él, no reemplazándolo):
- Herramientas del oficio: "professional cutting tools, measuring tape"
- Materiales relacionados: "colorful fabric rolls, thread spools"
- Superficie: "clean wooden table, marble surface"
- Ambiente: "clean workshop atmosphere, elegant studio backdrop"

**Construir `{ESTILO_FOTOGRÁFICO}`:** Una línea concreta, no genérica:
- "Commercial photography style, warm industrial lighting, sharp focus"
- "Product photography, soft natural lighting, shallow depth of field"
- "Editorial style, dramatic side lighting, clean composition"
- Evitar: "Professional lighting suitable for marketing" (demasiado vago)

### Instrucciones de edición según el tópico

La sección `{INSTRUCCIONES_DE_EDICIÓN}` cambia según la categoría del post.
Recuerda: solo describir el ENTORNO, nunca una acción para el producto.

| Tipo de tópico | Instrucciones de edición |
|---|---|
| Producto / servicio | "Place it on a clean, elegant surface with a soft blurred background and studio lighting that highlights the product's texture and details." |
| Tip del sector | "Place it on a professional {INDUSTRY} work table with a few neat trade tools nearby (organized, not cluttered). Clean background." |
| Caso de éxito / cliente satisfecho | "Place it in an elegant corporate setting, on a wood or marble surface, with warm lighting that conveys trust and quality." |
| Detrás de escena / proceso | "Place it in a tidy workshop or production environment. Manufacturing elements slightly out of focus in the background." |
| Tendencia / mercado | "Set it on a minimalist surface with a subtle gradient background. Contemporary editorial composition." |
| Fecha especial | "Place it on a table with {SPECIAL_DATE} decorations: {DECORACIÓN_ACORDE}. The product remains the absolute protagonist." |
| Nuevo lanzamiento | "Place it on a premium surface (marble, dark wood, or acrylic) with a clean gradient background and side lighting that highlights every detail." |

### Contexto del tópico

La sección `{CONTEXTO_DEL_TÓPICO_DEL_DÍA}` agrega ambientación temática:

```
{Si hay SPECIAL_DATE:
  "The setting should evoke {SPECIAL_DATE} without overshadowing the product."
}
{Si la categoría es "tip del sector":
  "Context: educational post about {TOPIC} — the atmosphere should convey
   professionalism and industry expertise."
}
{Si es genérico:
  "Today's post topic: {TOPIC}."
}
```

### Ejemplos multi-industria

*Textil — producto (foto casual de sesgo en escritorio desordenado):*
```
Professional B2B social media photo for Sesgo Express, a textile cutting
service company in Medellin Colombia.

Keep the main subject from the original photo but enhance it with
colorful sesgo bias tape rolls, professional fabric cutting tools,
and a clean textile workshop atmosphere.

Place it on a clean wooden table with a soft blurred background in
neutral tones. A few decorative textile elements nearby (small rolls
of different-colored bias tape, a measuring tape, folded fabrics
in the background) — all neat and aesthetic.

The main subject is the black sesgo rolls. Remove everything around it
that is not part of the product (papers, pens, invoices, desk items).

Commercial photography style, warm industrial lighting, sharp focus.
```

*Calzado — fecha especial (foto de botas en piso de bodega):*
```
Professional B2B social media photo for Botas García, a leather
footwear manufacturer.

Keep the main subject from the original photo but enhance it with
rustic wooden surface, autumn leaves, and small decorative pumpkins
slightly out of focus in the background.

Place it on a rustic wood surface with warm orange and golden tones.
Elegant autumnal atmosphere.

The main subject is the brown leather boots. Remove everything around
them that is not part of the product (boxes, warehouse floor, labels).

The setting should evoke Halloween without overshadowing the product.

Product photography, warm golden lighting, shallow depth of field.
```

*Alimentos — nuevo lanzamiento (foto de frascos de miel en cocina):*
```
Professional B2B social media photo for Miel del Valle, an artisanal
honey producer.

Keep the main subject from the original photo but enhance it with
natural elements: wild flowers, a small honeycomb piece, honey drops
on the surface — all neat and aesthetic.

Place it on a white marble surface with warm side lighting that makes
the honey glow through the glass. Soft background with golden-to-white
gradient.

The main subject is the honey jars. Remove everything around them that
is not part of the product (kitchen counter, utensils, wall background).

Product photography, warm side lighting, sharp focus on glass details.
```

*Tecnología — tip del sector (foto de gadget en escritorio):*
```
Professional B2B social media photo for TechFlow, a tech accessories
store.

Keep the main subject from the original photo but enhance it with a
minimalist light wood desk, a smartphone nearby as usage reference,
and a clean blurred background in soft gray tones.

Place it on a minimalist desk with studio lighting that highlights
the aluminum finish and blue LED indicator.

The main subject is the wireless charger. Remove everything around it
that is not part of the product (loose cables, other desk objects, papers).

Context: educational post about wireless charging — the atmosphere should
convey modern technology and simplicity.

Product photography, cool studio lighting, sharp focus.
```

---

## Ejemplos Text-to-Image (Modo A)

*Textil — Día de la Mujer:*
```
Soy dueño de Sesgo Express, una fábrica de sesgo textil.
Necesito crear una imagen para publicar en redes sociales.

La temática del post de hoy es: sesgo planchado para el Día de la Mujer.
La ocasión especial es: Día de la Mujer.

Crea una imagen festiva y atractiva para redes sociales que represente esta temática
en el contexto del sector textil. La imagen debe verse real y profesional,
sin texto ni logos superpuestos.
```

*Calzado — Halloween:*
```
Soy fabricante de calzado en Botas García.
Necesito crear una imagen para publicar en redes sociales.

La temática del post de hoy es: botas de cuero en Halloween.
La ocasión especial es: Halloween.

Crea una imagen oscura y creativa para redes sociales que evoque Halloween
en el contexto del calzado. La imagen debe verse real y profesional,
sin texto ni logos superpuestos.
```

*Manufactura — tendencia:*
```
Soy responsable de marketing en MetalParts, empresa de manufactura de piezas de metal.
Necesito crear una imagen para publicar en redes sociales.

La temática del post de hoy es: tendencias de automatización industrial 2026.

Crea una imagen editorial moderna que represente la automatización industrial.
Estilo editorial, composición limpia y contemporánea. La imagen debe verse real
y profesional, sin texto ni logos superpuestos.
```

*Alimentos — lanzamiento:*
```
Soy responsable de marketing en Miel del Valle, productora de miel artesanal.
Necesito crear una imagen para publicar en redes sociales.

La temática del post de hoy es: lanzamiento de nuestra miel de flores silvestres.

Crea una imagen hermosa para redes sociales con luz cálida y elementos naturales,
que destaque el lanzamiento del producto. La imagen debe verse real y profesional,
sin texto ni logos superpuestos.
```

---

## Sintaxis por herramienta

Con el prompt construido (text-to-image o edit-image), adaptarlo según la herramienta destino:

### fal-ai (recomendado)

**Text-to-image** → `fal-ai/nano-banana-2`:
```json
{
  "prompt": "{PROMPT}",
  "image_size": "square_hd",
  "num_images": 1,
  "enable_safety_checker": true
}
```

**Edit image** → `fal-ai/flux-pro/edit`:
```json
{
  "image_url": "{URL_O_DATA_URI_DE_LA_IMAGEN}",
  "prompt": "{PROMPT_EDIT}",
  "image_size": "square_hd",
  "num_images": 1,
  "safety_tolerance": "5"
}
```

→ Ver instrucciones completas de llamada API en `generate-image-ai.md`

### Midjourney

**Text-to-image:**
```
/imagine {PROMPT} --ar 1:1 --v 6 --style raw
```

**Edit image:** Subir la imagen de referencia y usar `--cref` o edición con Vary (Region):
```
/imagine {PROMPT_EDIT} --ar 1:1 --v 6 --style raw
```

- Ajustar `--ar` según formato: `1:1` (square), `4:5` (portrait), `16:9` (landscape)
- Agregar `--no text, logos, watermarks` si aparece texto no deseado

### DALL-E 3 (via ChatGPT o API)

**Text-to-image:**
```
{PROMPT}
Sin texto superpuesto, sin watermarks, sin logos.
```

**Edit image:** DALL-E 3 no soporta edición directa. Usar la descripción del producto
extraída de la foto como parte del prompt text-to-image.

- Usar `quality: "hd"` y `style: "natural"` en la API

### Adobe Firefly

```
{PROMPT}
```

- Pegar el prompt en el campo de texto de Firefly
- Para edit: usar "Generative Fill" con la imagen de referencia
- Ajustar "Photographic" en los controles de estilo de la interfaz
- Negative prompt en el campo separado: `text, logo, watermark, cartoon, illustration`

### Stable Diffusion / ComfyUI

**Text-to-image:**
```
{PROMPT}, (photorealistic:1.3), (high quality:1.4), (professional photography:1.2)
```

**Edit image:** Usar img2img o inpainting con el prompt de edición.

Negative prompt (campo separado):
```
text, watermark, logo, cartoon, illustration, low quality, blurry, deformed hands,
extra fingers, bad anatomy, AI artifacts
```

### Generic (cualquier herramienta)

```
{PROMPT}
```

Ambos tipos de prompt (text-to-image y edit-image) funcionan en modelos modernos.

---

## Output del skill

```json
{
  "mode": "text-to-image | edit-image",
  "tool": "{TOOL}",
  "format": "{FORMAT}",
  "prompt": "Soy {rol} de {COMPANY_NAME}... | Ambientar el producto con...",
  "negative_prompt": "text, watermark, logo, cartoon, illustration, low quality",
  "alternative_prompts": [
    "variación 1 del mismo tema con diferente enfoque visual",
    "variación 2 si la primera no produce el resultado esperado"
  ],
  "ready_for_generate_image_ai": true
}
```

---

## Flujo de uso con el Agente Publicador

**Opción A — Automático (recomendado):**
```
1. /publish-today llama a este skill para construir el prompt
2. → generate-image-ai ejecuta la generación con fal-ai/nano-banana-2
3. → imagen publicada directamente en Instagram/Facebook
```

**Opción B — Manual (cuando no hay FAL_KEY):**
```
1. /publish-today llama a este skill y obtiene el prompt
2. Usuario copia el prompt y lo usa en Midjourney/DALL-E/Firefly
3. Usuario proporciona la URL pública de la imagen generada
4. /publish-today publica el post con esa URL
```
