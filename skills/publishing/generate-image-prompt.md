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

> **Principio clave:** El prompt es conversacional, con la misma estructura del Modo B
> (edit-image). Debe sonar como si el dueño de la empresa le pidiera la imagen a un
> diseñador: quién soy, dónde estoy, qué producto, qué tema, cómo ambientar,
> qué debe ser el protagonista, y estilo fotográfico concreto.
> Las mismas reglas críticas del Modo B aplican aquí: no describir acciones,
> solo describir el entorno y la ambientación.

### Cadena de pensamiento para construir el prompt

Antes de escribir el prompt, pensar en estos 5 pasos:

1. **¿Quién soy?** — Nombre de la empresa, sector, ubicación. Ser específico.
2. **¿Qué producto?** — Usar la `technical_description` aprobada en `/init`.
   Describir el producto como se ve en la realidad (forma, color, material, tamaño).
3. **¿Cuál es el tema del día?** — El tópico del post y cómo se refleja en la
   ambientación de la imagen (elementos decorativos, superficie, fondo, atmósfera).
4. **¿Qué debe ser el protagonista?** — El producto siempre es el centro de atención.
   Los elementos decorativos y la ambientación acompañan, no compiten.
5. **¿Estilo fotográfico?** — Tipo de iluminación, enfoque, atmósfera. Concreto, no genérico.

### Plantilla base

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}
{Si hay LOCATION → agregar: en {LOCATION}}.

{Si hay PRODUCT_DESCRIPTION:
  Mi producto es {PRODUCT_DESCRIPTION}.
}

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: {TOPIC}.
{Si hay SPECIAL_DATE → agregar: La ocasión especial es {SPECIAL_DATE}.}

{INSTRUCCIONES_DE_AMBIENTACIÓN}

El protagonista de la imagen debe ser {ELEMENTO_PROTAGONISTA_DEL_PRODUCTO}.
Todo lo demás en la imagen debe acompañar al producto sin opacarlo.

{CONTEXTO_DEL_TÓPICO_DEL_DÍA}

{ESTILO_FOTOGRÁFICO}.
Sin texto, sin logos, sin watermarks superpuestos.
```

**Construir `{INSTRUCCIONES_DE_AMBIENTACIÓN}`:** Describir la escena completa donde
estará el producto. Incluir:
- Superficie donde va el producto (mesa de madera, mármol, superficie limpia)
- Elementos decorativos alrededor (2-4 elementos concretos del sector o del tema)
- Fondo (difuminado, gradiente, taller limpio, etc.)
- Atmósfera general (cálida, moderna, elegante, festiva)

### Instrucciones de ambientación según el tópico

| Tipo de tópico | Instrucciones de ambientación |
|---|---|
| Producto / servicio | "Quisiera que el producto esté sobre una superficie limpia y elegante, con fondo suave y difuminado, iluminación de estudio que resalte los detalles y la textura del producto. Algunos elementos del sector alrededor, ordenados y estéticos." |
| Tip del sector | "Quisiera que el producto esté sobre una mesa de trabajo profesional de {INDUSTRY}, con algunas herramientas del oficio al lado (ordenadas, no desordenadas). Fondo limpio que transmita profesionalismo." |
| Caso de éxito / cliente satisfecho | "Quisiera que el producto esté en un ambiente corporativo elegante, sobre una superficie de madera o mármol, con iluminación cálida que transmita confianza y calidad." |
| Detrás de escena / proceso | "Quisiera que el producto esté en un ambiente de taller o producción, pero ordenado y profesional. Elementos de manufactura al fondo, ligeramente desenfocados." |
| Tendencia / mercado | "Quisiera que el producto esté sobre una superficie minimalista, fondo con gradiente sutil. Composición editorial contemporánea." |
| Fecha especial | "Quisiera que el producto esté sobre una mesa con ambientación de {SPECIAL_DATE}: {DECORACIÓN_ACORDE}. El producto sigue siendo el protagonista absoluto." |
| Nuevo lanzamiento | "Quisiera que el producto esté sobre una superficie premium (mármol, madera oscura o acrílico), con fondo degradado limpio e iluminación lateral que destaque cada detalle." |

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
| **Anclar el sujeto** | "Mantén el sujeto principal de la foto original" | "Mantén los elementos visuales principales" (vago, el modelo reinterpreta) |
| **Solo cambiar el entorno** | "mejórala con [elementos alrededor]" | "Muestra la tela siendo cortada" (describe acción → transforma el producto) |
| **No describir acciones** | "herramientas de corte profesionales al lado" | "Muestra el corte a 45 grados" (el modelo cambia el producto) |
| **Nombrar la empresa** | "para Sesgo Express, empresa textil de Medellín" | "para marketing de sesgo textil" (genérico, el modelo improvisa) |
| **Estilo fotográfico concreto** | "Fotografía comercial, iluminación cálida industrial, enfoque nítido" | "Iluminación profesional para marketing" (vago) |
| **Enriquecer, no reemplazar** | "mejórala con rollos de colores, herramientas, taller limpio" | "transfórmala en foto de estudio profesional" (el modelo recrea todo) |

> **Resumen:** Nunca le digas al modelo qué HACER con el producto. Solo dile qué PONER ALREDEDOR.
> El producto se queda exactamente como está en la foto original.

### Cadena de pensamiento para construir el prompt

Antes de escribir el prompt, pensar en estos 5 pasos:

1. **¿Quién soy?** — Nombre de la empresa, sector, ubicación. Ser específico.
2. **¿Qué se ve en la foto?** — Usar la `technical_description` del producto aprobada
   en `/init`. Si no existe, describir lo que se observa en la imagen.
3. **¿Qué quiero que cambie del ENTORNO?** — Limpiar el fondo, remover objetos, mejorar la superficie.
   La foto original suele ser casual (escritorio desordenado, piso, fondo de bodega).
   **NUNCA describir una acción para el producto** (no "muestra cortando", no "muestra siendo usado").
   Solo describir qué elementos agregar ALREDEDOR: herramientas, decoración, superficie, fondo.
4. **¿Cómo debe verse el resultado?** — Estilo fotográfico concreto: tipo de iluminación
   (cálida industrial, suave natural, lateral dramática), enfoque (nítido, profundidad de campo),
   atmósfera (taller limpio, estudio elegante, minimalista).
5. **¿Para qué plataforma?** — Instagram, redes sociales, página web.
   Siempre: sin texto superpuesto, sin logos, sin watermarks.

### Plantilla base

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}
{Si hay LOCATION → agregar: en {LOCATION}}.
Esta es una imagen de {TECHNICAL_DESCRIPTION_RESUMIDA}.

Me gustaría que volvieras esta foto más profesional y realista, lista para
ser publicada en los canales y redes sociales oficiales de la marca
(Instagram, Facebook, página web). La imagen debe verse como si hubiera
sido tomada y ambientada por un equipo experto en fotografía de producto.

Mantén el sujeto principal de la foto original pero mejórala con
{ELEMENTOS_DEL_ENTORNO}.

{INSTRUCCIONES_DE_EDICIÓN}

La parte principal es {ELEMENTO_PROTAGONISTA_DEL_PRODUCTO}. Las cosas que están
alrededor que no son parte del producto, remuévelas.

{CONTEXTO_DEL_TÓPICO_DEL_DÍA}

{ESTILO_FOTOGRÁFICO}.
Sin texto, sin logos, sin watermarks superpuestos.
```

**Construir `{ELEMENTOS_DEL_ENTORNO}`:** Listar 2-4 elementos concretos que van
ALREDEDOR del producto (no sobre él, no reemplazándolo):
- Herramientas del oficio: "herramientas de corte profesionales, cinta métrica"
- Materiales relacionados: "rollos de tela de colores, carretes de hilo"
- Superficie: "mesa de madera limpia, superficie de mármol"
- Ambiente: "ambiente de taller limpio, fondo de estudio elegante"

**Construir `{ESTILO_FOTOGRÁFICO}`:** Una línea concreta, no genérica:
- "Fotografía comercial, iluminación cálida industrial, enfoque nítido"
- "Fotografía de producto, iluminación natural suave, poca profundidad de campo"
- "Estilo editorial, iluminación lateral dramática, composición limpia"
- Evitar: "Iluminación profesional apta para marketing" (demasiado vago)

### Instrucciones de edición según el tópico

La sección `{INSTRUCCIONES_DE_EDICIÓN}` cambia según la categoría del post.
Recuerda: solo describir el ENTORNO, nunca una acción para el producto.

| Tipo de tópico | Instrucciones de edición |
|---|---|
| Producto / servicio | "Quisiera que el producto esté sobre una superficie limpia y elegante, que el fondo sea suave y difuminado, con iluminación de estudio que resalte los detalles y la textura del producto." |
| Tip del sector | "Quisiera que el producto esté sobre una mesa de trabajo profesional de {INDUSTRY}, con algunas herramientas del oficio al lado (ordenadas, no desordenadas). Fondo limpio." |
| Caso de éxito / cliente satisfecho | "Quisiera que el producto esté en un ambiente corporativo elegante, sobre una superficie de madera o mármol, con iluminación cálida que transmita confianza y calidad." |
| Detrás de escena / proceso | "Quisiera que el producto esté en un ambiente de taller o producción, pero ordenado y profesional. Elementos de manufactura al fondo, ligeramente desenfocados." |
| Tendencia / mercado | "Quisiera que el producto esté sobre una superficie minimalista, fondo con gradiente sutil. Composición editorial contemporánea." |
| Fecha especial | "Quisiera que el producto esté sobre una mesa con ambientación de {SPECIAL_DATE}: {DECORACIÓN_ACORDE}. El producto sigue siendo el protagonista absoluto." |
| Nuevo lanzamiento | "Quisiera que el producto esté sobre una superficie premium (mármol, madera oscura o acrílico), con fondo degradado limpio e iluminación lateral que destaque cada detalle." |

### Contexto del tópico

La sección `{CONTEXTO_DEL_TÓPICO_DEL_DÍA}` agrega ambientación temática:

```
{Si hay SPECIAL_DATE:
  "La ambientación debe evocar {SPECIAL_DATE} sin opacar al producto."
}
{Si la categoría es "tip del sector":
  "Es un post educativo sobre {TOPIC}, el ambiente debe transmitir
   profesionalismo y conocimiento del sector."
}
{Si es genérico:
  "El tema del post de hoy es: {TOPIC}."
}
```

### Ejemplos multi-industria

*Textil — producto (foto casual de sesgo en escritorio desordenado):*
```
Soy fabricante de sesgo textil y mi fábrica se llama Sesgo Express,
en Medellín Colombia.
Esta es una imagen del sesgo negro que fabrico, una torta de sesgo
planchado envuelta en plástico transparente.

Me gustaría que volvieras esta foto más profesional y realista, lista para
ser publicada en los canales y redes sociales oficiales de la marca
(Instagram, Facebook, página web). La imagen debe verse como si hubiera
sido tomada y ambientada por un equipo experto en fotografía de producto.

Mantén el sujeto principal de la foto original pero mejórala con
rollos de sesgo de colores, herramientas de corte profesionales
y un ambiente de taller textil limpio.

Quisiera que el sesgo esté sobre una mesa de madera limpia y elegante,
que el fondo sea suave y difuminado con tonos neutros. Que se vean
algunos elementos textiles decorativos alrededor (pequeños rollos de
sesgo de otros colores, una cinta métrica, telas dobladas al fondo)
pero todo ordenado y estético.

La parte principal es el sesgo negro. Las cosas que están alrededor
que no son parte del producto (papeles, bolígrafos, facturas,
objetos de escritorio), remuévelas.

Fotografía comercial, iluminación cálida industrial, enfoque nítido.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Calzado — fecha especial (foto de botas en piso de bodega):*
```
Soy fabricante de calzado en Botas García.
Esta es una imagen de mis botas de cuero marrón con suela de caucho
y costuras visibles estilo artesanal.

Me gustaría que volvieras esta foto más profesional y realista, lista para
ser publicada en los canales y redes sociales oficiales de la marca
(Instagram, Facebook, página web). La imagen debe verse como si hubiera
sido tomada y ambientada por un equipo experto en fotografía de producto.

Mantén el sujeto principal de la foto original pero mejórala con
superficie de madera rústica, hojas secas y calabazas pequeñas
ligeramente desenfocadas al fondo.

Quisiera que las botas estén sobre madera rústica con tonos cálidos
naranjas y dorados. Ambiente otoñal elegante.

La parte principal son las botas. Las cosas que están alrededor que
no son parte del producto (cajas, piso de bodega, etiquetas), remuévelas.

La ambientación debe evocar Halloween sin opacar al producto.

Fotografía de producto, iluminación cálida dorada, poca profundidad de campo.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Alimentos — nuevo lanzamiento (foto de frascos de miel en cocina):*
```
Soy responsable de marketing en Miel del Valle, productora de miel artesanal.
Esta es una imagen de nuestros frascos de miel de flores silvestres,
frascos de vidrio con miel dorada y tapa metálica plateada.

Me gustaría que volvieras esta foto más profesional y realista, lista para
ser publicada en los canales y redes sociales oficiales de la marca
(Instagram, Facebook, página web). La imagen debe verse como si hubiera
sido tomada y ambientada por un equipo experto en fotografía de producto.

Mantén el sujeto principal de la foto original pero mejórala con
elementos naturales: flores silvestres, un pequeño trozo de panal,
gotas de miel sobre la superficie — todo ordenado y estético.

Quisiera que los frascos estén sobre una superficie de mármol blanco,
con iluminación lateral cálida que haga brillar la miel a través
del vidrio. Fondo suave con gradiente dorado a blanco.

La parte principal son los frascos de miel. Las cosas que están alrededor
que no son parte del producto (mesón de cocina, utensilios, fondo
de pared), remuévelas.

Fotografía de producto, iluminación lateral cálida, enfoque nítido en detalles del vidrio.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Tecnología — tip del sector (foto de gadget en escritorio):*
```
Soy responsable de marketing en TechFlow, tienda de accesorios tecnológicos.
Esta es una imagen de nuestro cargador inalámbrico circular, base de
aluminio con superficie de carga negra y LED indicador azul.

Me gustaría que volvieras esta foto más profesional y realista, lista para
ser publicada en los canales y redes sociales oficiales de la marca
(Instagram, Facebook, página web). La imagen debe verse como si hubiera
sido tomada y ambientada por un equipo experto en fotografía de producto.

Mantén el sujeto principal de la foto original pero mejórala con
un escritorio minimalista de madera clara, un smartphone al lado
como referencia de uso, y fondo difuminado en tonos grises suaves.

Quisiera que el cargador esté sobre un escritorio minimalista con
iluminación de estudio que resalte el acabado de aluminio y el LED azul.

La parte principal es el cargador inalámbrico. Las cosas que están
alrededor que no son parte del producto (cables sueltos, otros
objetos de escritorio, papeles), remuévelas.

Es un post educativo sobre carga inalámbrica, el ambiente debe
transmitir tecnología moderna y simplicidad.

Fotografía de producto, iluminación de estudio fría, enfoque nítido.
Sin texto, sin logos, sin watermarks superpuestos.
```

---

## Ejemplos Text-to-Image (Modo A)

*Textil — Día de la Mujer (con producto):*
```
Soy dueño de Sesgo Express, una fábrica de sesgo textil en Medellín, Colombia.

Mi producto es sesgo planchado: cinta al bies de poliéster enrollada en
tortas de 50 metros, disponible en colores vibrantes (negro, blanco, rojo,
azul, verde). Cada torta viene envuelta en plástico transparente.

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: sesgo planchado para el Día de la Mujer.
La ocasión especial es el Día de la Mujer.

Quisiera que las tortas de sesgo estén sobre una mesa de madera cálida
y limpia, con flores de colores pastel suaves al fondo ligeramente
desenfocadas (rosas, blancas, lavanda), y una tela de algodón blanca
o crema como base decorativa. Atmósfera tierna y acogedora.

El protagonista de la imagen deben ser las tortas de sesgo de colores.
Todo lo demás en la imagen debe acompañar al producto sin opacarlo.

La ambientación debe evocar el Día de la Mujer sin opacar al producto.
Tonos cálidos, rosados suaves y blancos.

Fotografía comercial de producto, iluminación natural cálida y suave,
enfoque nítido en las tortas de sesgo.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Calzado — Halloween (con producto):*
```
Soy fabricante de calzado en Botas García, en Bucaramanga, Colombia.

Mi producto son botas de cuero marrón con suela de caucho y costuras
visibles estilo artesanal.

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: botas de cuero en Halloween.
La ocasión especial es Halloween.

Quisiera que las botas estén sobre una superficie de madera rústica,
con hojas secas y calabazas pequeñas como elementos decorativos al
fondo (ligeramente desenfocados). Iluminación cálida con tonos
naranjas y dorados. Ambiente otoñal elegante.

El protagonista de la imagen deben ser las botas. Todo lo demás en
la imagen debe acompañar al producto sin opacarlo.

La ambientación debe evocar Halloween sin opacar al producto.

Fotografía de producto, iluminación cálida dorada, poca profundidad
de campo.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Manufactura — tendencia (sin producto específico):*
```
Soy responsable de marketing en MetalParts, empresa de manufactura
de piezas de metal en Monterrey, México.

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: tendencias de automatización industrial 2026.

Quisiera una imagen que muestre un ambiente de manufactura moderno:
brazo robótico industrial en acción, piezas de metal con acabado
brillante sobre una mesa de trabajo, chispas de soldadura al fondo
(ligeramente desenfocadas). Fondo de planta industrial limpia y
organizada con tonos metálicos y azules.

El protagonista de la imagen debe ser la automatización y las piezas
de metal. El ambiente debe transmitir tecnología moderna y precisión.

Estilo editorial, iluminación industrial dramática, composición limpia
y contemporánea.
Sin texto, sin logos, sin watermarks superpuestos.
```

*Alimentos — lanzamiento (con producto):*
```
Soy responsable de marketing en Miel del Valle, productora de miel
artesanal en Cali, Colombia.

Mi producto son frascos de miel de flores silvestres: frascos de vidrio
con miel dorada y tapa metálica plateada, etiqueta artesanal.

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: lanzamiento de nuestra miel de flores silvestres.

Quisiera que los frascos de miel estén sobre una superficie de mármol
blanco, con algunos elementos naturales alrededor (flores silvestres,
un pequeño trozo de panal, gotas de miel sobre la superficie) todo
ordenado y estético. Iluminación lateral cálida que haga brillar la
miel a través del vidrio. Fondo suave con gradiente dorado a blanco.

El protagonista de la imagen deben ser los frascos de miel. Todo lo
demás en la imagen debe acompañar al producto sin opacarlo.

Es el lanzamiento de nuestra nueva línea, la presentación debe verse
premium y destacar cada detalle del producto.

Fotografía de producto, iluminación lateral cálida, enfoque nítido
en detalles del vidrio.
Sin texto, sin logos, sin watermarks superpuestos.
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

**Edit image** → `fal-ai/nano-banana-2/edit`:
```json
{
  "image_url": "{URL_O_DATA_URI_DE_LA_IMAGEN}",
  "prompt": "{PROMPT_EDIT}",
  "image_size": "square_hd",
  "num_images": 1,
  "enable_safety_checker": true
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
