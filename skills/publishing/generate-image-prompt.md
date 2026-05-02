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
> Genera una **instrucción de edición** que describe qué cambiar en la foto existente,
> no una escena completa. El producto ya está en la imagen — el prompt indica cómo
> transformar el contexto, fondo o ambientación alrededor de él.

> **Principio clave:** El prompt de edición debe ser corto y directivo. No describe la
> escena entera — describe solo **lo que debe cambiar**. El modelo preserva lo que no
> se menciona.

**Plantilla base:**

```
{INSTRUCCIÓN_PRINCIPAL_SEGÚN_TÓPICO}.
{Si hay SPECIAL_DATE → agregar contexto de la fecha.}
Mantener el producto como protagonista. Estilo profesional para redes sociales,
sin texto ni logos superpuestos.
```

**Instrucción principal según el tópico:**

| Tipo de tópico | Instrucción de edición |
|---|---|
| Tip del sector | "Ambientar el producto en un espacio de trabajo profesional de {INDUSTRY}, con herramientas y elementos propios del oficio alrededor." |
| Caso de éxito / cliente satisfecho | "Colocar el producto en un ambiente corporativo elegante que transmita éxito y confianza, con iluminación cálida." |
| Detrás de escena / proceso | "Situar el producto en un ambiente de taller o planta de producción, con elementos de manufactura alrededor." |
| Tendencia / mercado | "Darle al producto un entorno editorial moderno: fondo limpio, composición contemporánea, iluminación de estudio." |
| Fecha especial | "Ambientar el producto con decoración y elementos visuales de {SPECIAL_DATE}. Contexto festivo y acorde a la celebración." |
| Nuevo lanzamiento | "Presentar el producto como protagonista absoluto: fondo limpio degradado, iluminación destacada, ángulo premium." |
| Producto / servicio | "Mostrar el producto en un contexto atractivo de uso real en {INDUSTRY}, con ambientación natural y profesional." |

**Ejemplos multi-industria:**

*Textil — Día de la Mujer:*
```
Ambientar el producto con decoración festiva del Día de la Mujer: flores,
tonos morados y rosados, ambiente cálido y celebratorio.
Mantener el producto como protagonista. Estilo profesional para redes sociales,
sin texto ni logos superpuestos.
```

*Calzado — Halloween:*
```
Situar las botas en un ambiente oscuro y misterioso de Halloween: hojas secas,
calabazas, iluminación dramática con tonos naranjas y negros.
Mantener el producto como protagonista. Estilo profesional para redes sociales,
sin texto ni logos superpuestos.
```

*Manufactura — tendencia:*
```
Darle al producto un entorno editorial moderno: fondo de líneas geométricas limpias,
iluminación de estudio, composición contemporánea que transmita innovación.
Mantener el producto como protagonista. Estilo profesional para redes sociales,
sin texto ni logos superpuestos.
```

*Alimentos — lanzamiento:*
```
Presentar los frascos como protagonistas: fondo degradado dorado a blanco,
iluminación lateral cálida, gotas de miel en la superficie, elementos naturales
como flores silvestres alrededor.
Mantener el producto como protagonista. Estilo profesional para redes sociales,
sin texto ni logos superpuestos.
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
