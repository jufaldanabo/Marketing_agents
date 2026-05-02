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

### Cadena de pensamiento para construir el prompt

Antes de escribir el prompt, pensar en estos 5 pasos:

1. **¿Quién soy?** — Contexto del negocio (empresa, sector)
2. **¿Qué se ve en la foto?** — Usar la `technical_description` del producto aprobada
   en `/init`. Si no existe, describir lo que se observa en la imagen.
3. **¿Qué quiero que cambie?** — Limpiar el fondo, remover objetos, mejorar la presentación.
   La foto original suele ser casual (escritorio desordenado, piso, fondo de bodega).
   El resultado debe verse como fotografía de catálogo profesional.
4. **¿Cómo debe verse el resultado?** — Superficie donde va el producto, fondo,
   iluminación, elementos decorativos que acompañen según el tópico del día.
5. **¿Para qué plataforma?** — Instagram, redes sociales, página web.
   Siempre: sin texto superpuesto, sin logos, sin watermarks.

### Plantilla base

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}.
Esta es una imagen de {TECHNICAL_DESCRIPTION_RESUMIDA}.

Me gustaría que volvieras esta foto más profesional, lista para ser publicada
en Instagram, redes sociales y página web.

{INSTRUCCIONES_DE_EDICIÓN}

La parte principal es {ELEMENTO_PROTAGONISTA_DEL_PRODUCTO}. Las cosas que están
alrededor que no son parte del producto, remuévelas.

{CONTEXTO_DEL_TÓPICO_DEL_DÍA}

La imagen debe verse como fotografía de catálogo profesional: iluminación suave
y natural, composición limpia, colores fieles al producto real.
Sin texto, sin logos, sin watermarks superpuestos.
```

### Instrucciones de edición según el tópico

La sección `{INSTRUCCIONES_DE_EDICIÓN}` cambia según la categoría del post:

| Tipo de tópico | Instrucciones de edición |
|---|---|
| Producto / servicio | "Quisiera que el producto esté sobre una superficie limpia y elegante, que el fondo sea suave y difuminado, con iluminación de estudio que resalte los detalles y la textura del producto." |
| Tip del sector | "Quisiera que el producto esté sobre una mesa de trabajo profesional de {INDUSTRY}, con algunos elementos del oficio alrededor (pero ordenados y estéticos, no desordenados). Fondo limpio." |
| Caso de éxito / cliente satisfecho | "Quisiera que el producto esté en un ambiente corporativo elegante, sobre una superficie de madera o mármol, con iluminación cálida que transmita confianza y calidad." |
| Detrás de escena / proceso | "Quisiera que el producto esté en un ambiente de taller o producción, pero ordenado y profesional. Elementos de manufactura al fondo, ligeramente desenfocados." |
| Tendencia / mercado | "Quisiera que el producto tenga un entorno editorial moderno: superficie minimalista, fondo con gradiente sutil, composición contemporánea tipo revista." |
| Fecha especial | "Quisiera que el producto esté sobre una mesa con ambientación de {SPECIAL_DATE}: {DECORACIÓN_ACORDE}. Manteniendo el producto como protagonista absoluto." |
| Nuevo lanzamiento | "Quisiera que el producto esté sobre una superficie premium (mármol, madera oscura o acrílico), con fondo degradado limpio e iluminación lateral que destaque cada detalle." |

### Contexto del tópico

La sección `{CONTEXTO_DEL_TÓPICO_DEL_DÍA}` agrega ambientación temática:

```
{Si hay SPECIAL_DATE:
  "El post es por {SPECIAL_DATE}, así que la ambientación y los elementos
   decorativos deben evocar esa fecha sin opacar al producto."
}
{Si la categoría es "tip del sector":
  "Es un post educativo sobre {TOPIC}, por lo que el ambiente debe
   transmitir profesionalismo y conocimiento del sector."
}
{Si es genérico:
  "El tema del post de hoy es: {TOPIC}."
}
```

### Ejemplos multi-industria

*Textil — producto (foto casual de sesgo en escritorio desordenado):*
```
Soy fabricante de sesgo textil y mi fábrica se llama Sesgo Express.
Esta es una imagen del sesgo negro que fabrico, una torta de sesgo
planchado envuelta en plástico transparente.

Me gustaría que volvieras esta foto más profesional, lista para ser
publicada en Instagram, redes sociales y página web.

Quisiera que el sesgo esté sobre una mesa de madera limpia y elegante,
que el fondo sea suave y difuminado con tonos neutros. Que se vean
algunos elementos textiles decorativos alrededor (pequeños rollos de
sesgo de otros colores, una cinta métrica, telas dobladas al fondo)
pero todo ordenado y estético.

La parte principal es el sesgo negro. Las cosas que están alrededor
que no son parte del producto (papeles, bolígrafos, facturas,
objetos de escritorio), remuévelas.

La imagen debe verse como fotografía de catálogo profesional: iluminación
suave y natural, composición limpia, colores fieles al producto real.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Calzado — fecha especial (foto de botas en piso de bodega):*
```
Soy fabricante de calzado en Botas García.
Esta es una imagen de mis botas de cuero marrón con suela de caucho
y costuras visibles estilo artesanal.

Me gustaría que volvieras esta foto más profesional, lista para ser
publicada en Instagram, redes sociales y página web.

Quisiera que las botas estén sobre una superficie de madera rústica,
con hojas secas y calabazas pequeñas como elementos decorativos
al fondo (ligeramente desenfocados). Iluminación cálida con tonos
naranjas y dorados. Ambiente otoñal elegante.

La parte principal son las botas. Las cosas que están alrededor que
no son parte del producto (cajas, piso de bodega, etiquetas), remuévelas.

El post es por Halloween, así que la ambientación y los elementos
decorativos deben evocar esa fecha sin opacar al producto.

La imagen debe verse como fotografía de catálogo profesional: iluminación
suave y natural, composición limpia, colores fieles al producto real.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Alimentos — nuevo lanzamiento (foto de frascos de miel en cocina):*
```
Soy responsable de marketing en Miel del Valle, productora de miel artesanal.
Esta es una imagen de nuestros frascos de miel de flores silvestres,
frascos de vidrio con miel dorada y tapa metálica plateada.

Me gustaría que volvieras esta foto más profesional, lista para ser
publicada en Instagram, redes sociales y página web.

Quisiera que los frascos estén sobre una superficie de mármol blanco,
con algunos elementos naturales alrededor (flores silvestres, un panal
pequeño, gotas de miel en la superficie) todo ordenado y estético.
Iluminación lateral cálida que haga brillar la miel a través del vidrio.
Fondo suave con gradiente dorado a blanco.

La parte principal son los frascos de miel. Las cosas que están alrededor
que no son parte del producto (mesón de cocina, utensilios, fondo
de pared), remuévelas.

Es el lanzamiento de nuestra nueva línea, por lo que la presentación
debe verse premium y destacar cada detalle del producto.

La imagen debe verse como fotografía de catálogo profesional: iluminación
suave y natural, composición limpia, colores fieles al producto real.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Tecnología — tip del sector (foto de gadget en escritorio):*
```
Soy responsable de marketing en TechFlow, tienda de accesorios tecnológicos.
Esta es una imagen de nuestro cargador inalámbrico circular, base de
aluminio con superficie de carga negra y LED indicador azul.

Me gustaría que volvieras esta foto más profesional, lista para ser
publicada en Instagram, redes sociales y página web.

Quisiera que el cargador esté sobre un escritorio minimalista de madera
clara, con un smartphone apoyado al lado (como referencia de uso).
Fondo limpio y difuminado con tonos grises suaves. Iluminación de
estudio que resalte el acabado de aluminio y el LED azul.

La parte principal es el cargador inalámbrico. Las cosas que están
alrededor que no son parte del producto (cables sueltos, otros
objetos de escritorio, papeles), remuévelas.

Es un post educativo sobre carga inalámbrica, por lo que el ambiente
debe transmitir tecnología moderna y simplicidad.

La imagen debe verse como fotografía de catálogo profesional: iluminación
suave y natural, composición limpia, colores fieles al producto real.
Sin texto, sin logos, sin watermarks superpuestos.
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
