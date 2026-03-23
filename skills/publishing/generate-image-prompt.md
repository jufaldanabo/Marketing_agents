# Skill: generate-image-prompt

**Propósito**: Genera un prompt conversacional con contexto de negocio para herramientas
de imagen IA: `fal-ai/nano-banana-2`, Midjourney, DALL-E 3, Adobe Firefly o Stable Diffusion.
Se usa cuando el usuario quiere ejecutar la generación manualmente o como paso previo
a `generate-image-ai`.
**Modelo**: `claude-sonnet-4-6`
**Usado por**: `publisher-agent.md`, `/publish-today`

---

## Por qué este skill es crítico

Instagram requiere imagen para publicar en feed. Sin imagen, el Agente Publicador
solo puede publicar en Facebook. Este skill genera el prompt necesario para crear la imagen,
ya sea de forma automática (via `generate-image-ai`) o manualmente con Midjourney/DALL-E/Firefly.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `topic` | string | Tema del post | "tendencias de embalaje sostenible" |
| `company_name` | string | Nombre de la empresa | "Botas García" |
| `industry` | string | Sector industrial | "calzado" |
| `brand_style` | string | Estilo visual (opcional) | "colores tierra, minimalista" |
| `special_date` | string | Fecha especial (opcional) | "Día de la Mujer" |
| `tool` | enum | Herramienta destino | `fal-ai` / `midjourney` / `dalle` / `firefly` / `stable-diffusion` / `generic` |
| `format` | enum | Formato de la imagen | `square` (1:1) / `portrait` (4:5) / `landscape` (16:9) |

## Especificaciones por plataforma

| Plataforma | Formato recomendado | Resolución mínima |
|---|---|---|
| Instagram Feed | 1:1 (cuadrado) o 4:5 (portrait) | 1080×1080 px |
| Instagram Stories | 9:16 (vertical) | 1080×1920 px |
| Facebook Feed | 1:1 o 16:9 | 1200×630 px |
| LinkedIn | 1.91:1 | 1200×627 px |

---

## Construir el prompt conversacional

> **Principio clave:** Los modelos modernos (nano-banana-2, FLUX, DALL-E 3) responden mejor
> a lenguaje conversacional con contexto de negocio que a descripciones técnicas de fotografía.
> El prompt debe sonar como si el dueño de la empresa le pidiera la imagen a un diseñador.

**Plantilla base:**

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}.
Necesito crear una imagen para publicar en redes sociales.

La temática del post de hoy es: {TOPIC}.
{Si hay SPECIAL_DATE → agregar: La ocasión especial es: {SPECIAL_DATE}.}
{Si hay brand_style → agregar: El estilo visual de mi marca es: {BRAND_STYLE}.}

Crea una imagen atractiva y creativa para redes sociales que represente esta temática
en el contexto de {INDUSTRY}. La imagen debe verse real y profesional,
sin texto ni logos superpuestos.
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

## Ejemplos multi-industria

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

Con el prompt conversacional construido, adaptarlo según la herramienta destino:

### fal-ai/nano-banana-2 (recomendado)

Pasar el prompt directamente al skill `generate-image-ai` — no requiere adaptación:

```json
{
  "prompt": "{PROMPT_CONVERSACIONAL}",
  "image_size": "square_hd",
  "num_images": 1,
  "enable_safety_checker": true
}
```

→ Ver instrucciones completas de llamada API en `generate-image-ai.md`

### Midjourney

```
/imagine {PROMPT_CONVERSACIONAL} --ar 1:1 --v 6 --style raw
```

- Pegar el prompt conversacional directamente en `/imagine`
- Ajustar `--ar` según formato: `1:1` (square), `4:5` (portrait), `16:9` (landscape)
- Agregar `--no text, logos, watermarks` si aparece texto no deseado

### DALL-E 3 (via ChatGPT o API)

```
{PROMPT_CONVERSACIONAL}
Sin texto superpuesto, sin watermarks, sin logos.
```

- El prompt conversacional funciona directo — no requiere adaptación técnica
- Agregar "Sin texto, sin watermarks, sin logos" al final
- Usar `quality: "hd"` y `style: "natural"` en la API

### Adobe Firefly

```
{PROMPT_CONVERSACIONAL}
```

- Pegar el prompt en el campo de texto de Firefly
- Ajustar "Photographic" en los controles de estilo de la interfaz
- Negative prompt en el campo separado: `text, logo, watermark, cartoon, illustration`

### Stable Diffusion / ComfyUI

```
{PROMPT_CONVERSACIONAL}, (photorealistic:1.3), (high quality:1.4), (professional photography:1.2)
```

Negative prompt (campo separado):
```
text, watermark, logo, cartoon, illustration, low quality, blurry, deformed hands,
extra fingers, bad anatomy, AI artifacts
```

### Generic (cualquier herramienta)

```
{PROMPT_CONVERSACIONAL}
```

El prompt conversacional funciona en cualquier modelo moderno sin adaptación.

---

## Output del skill

```json
{
  "tool": "{TOOL}",
  "format": "{FORMAT}",
  "prompt": "Soy {rol} de {COMPANY_NAME}, una empresa de {INDUSTRY}...",
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
