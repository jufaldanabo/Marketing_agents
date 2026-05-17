# Skill: generate-image-ai

Genera una imagen publicitaria B2B usando `fal-ai/nano-banana-2` a partir del contexto
de la empresa, las fotos de referencia del producto y la temática del post del día.

Usa **prompts conversacionales con contexto de negocio** ("soy fabricante de X, necesito
una imagen para redes sociales, el tema de hoy es Y") que producen mejores resultados
que los prompts técnicos de fotografía. Cuando hay fotos de referencia, las pasa al modelo
como base visual (img2img) junto con el prompt conversacional.

Devuelve una **URL pública** lista para usar directamente en Instagram Graph API.

---

## Variables requeridas

| Variable | Descripción |
|---|---|
| `FAL_KEY` | API key de fal.ai — requerida para img2img y text-to-image |

Obtener `FAL_KEY`: https://fal.ai → Dashboard → API Keys

---

## Inputs del skill

```
brand_style      → JSON de .claude/brand-images/brand-style.json (o null si no existe)
topic            → Tópico del post del día
category         → Categoría del contenido
company_name     → Nombre de la empresa
industry         → Sector de la empresa
special_date     → Fecha especial si aplica (o null)
platform         → "instagram" (1:1) | "facebook" (1.91:1)
product_slug     → Slug del producto a usar (o null para auto-detectar desde topic/category)
```

---

## Instrucciones para Claude

> **🔒 REGLA FUNDAMENTAL — NO NEGOCIABLE:**
> Las fotos de referencia del producto son **solo input para la generación de IA**.
> La imagen que se publica en redes sociales es **SIEMPRE una imagen nueva generada por IA**,
> nunca la foto original. Si hay fotos de referencia disponibles → obligatoriamente img2img.
> Si no hay fotos → generar de texto. En ningún caso publicar una foto sin procesar.

> **🔒 REGLA DE IDIOMA — OBLIGATORIA:**
> El prompt generado DEBE estar en **español**, en **primera persona**, con **tono conversacional**.
> NUNCA en inglés. NUNCA como instrucción técnica de stock photography.
> Si el prompt resultante contiene frases como "Professional product photography",
> "colorful rolls", "neatly arranged", "warm lighting" → ESTÁ MAL. Borrar y regenerar en español.

---

### Paso 0 — Seleccionar producto y obtener imagen de referencia

Antes de construir el prompt, identificar qué producto usar y si hay fotos disponibles.

#### 0.1 — Leer catálogo de productos

```bash
cat .claude/brand-images/products/product-catalog.json 2>/dev/null
```

- Si el archivo **no existe** → `mode = "text"`, `has_catalog = false` → saltar al Paso 1
- Si el archivo **existe** → continuar con 0.2

#### 0.2 — Seleccionar el producto más relevante

Elegir el producto que mejor coincida con `topic` y `category` del post:

**Reglas de selección (en orden de prioridad):**
1. Si `product_slug` fue pasado explícitamente → usarlo sin evaluar
2. Comparar palabras clave de `topic` y `category` contra los `keywords` de cada producto
3. Si hay un solo producto en el catálogo → usarlo siempre
4. Si hay múltiples sin coincidencia clara → usar el `default_product` del catálogo

#### 0.3 — Verificar si hay imágenes de referencia

```bash
PRODUCT_SLUG="{SLUG_SELECCIONADO}"
ls .claude/brand-images/products/$PRODUCT_SLUG/ 2>/dev/null | grep -E "\.(jpg|jpeg|png|webp)$"
```

- **Con imágenes** → `mode = "edit-image"` (PREFERIDO) → continuar con 0.4
  > La foto de referencia es el input para la edición, no la imagen final.
  > `REF_IMAGE_PATH` se usa únicamente para pasar a la API. Nunca como `image_url` de publicación.
- **Sin imágenes** → `mode = "text-to-image"` → saltar al Paso 1

#### 0.4 — Preparar imagen de referencia (solo modo img2img)

Seleccionar la primera imagen disponible y codificar para la API:

```bash
REF_IMAGE=$(ls .claude/brand-images/products/$PRODUCT_SLUG/ | grep -E "\.(jpg|jpeg|png|webp)$" | head -1)
REF_IMAGE_PATH=".claude/brand-images/products/$PRODUCT_SLUG/$REF_IMAGE"

# Codificar como base64 con data URI
BASE64_IMG=$(base64 -i "$REF_IMAGE_PATH" 2>/dev/null || base64 "$REF_IMAGE_PATH")
EXT="${REF_IMAGE##*.}"
MIME_TYPE="image/jpeg"
[ "$EXT" = "png" ] && MIME_TYPE="image/png"
[ "$EXT" = "webp" ] && MIME_TYPE="image/webp"
IMAGE_DATA_URI="data:$MIME_TYPE;base64,$BASE64_IMG"
```

Guardar para uso posterior:
- `PRODUCT_SLUG` → para metadata y logs
- `REF_IMAGE_PATH` → para verificación visual
- `IMAGE_DATA_URI` → para llamada API en Paso 3B
- `mode = "edit-image"` → determina qué modelo y prompt usar

> Usar `fal-ai/nano-banana-2/edit` con `image_url` + prompt de edición.

---

### Paso 1 — Verificar FAL_KEY

```bash
# Cargar .env si existe (local), en Railway las vars ya están en el entorno
[ -f .env ] && export $(grep -v '^#' .env | xargs)

# Verificar que FAL_KEY está configurada
[ -n "$FAL_KEY" ] && echo "fal" || echo "none"
```

| Estado | Con imagen referencia (`edit-image`) | Sin imagen referencia (`text-to-image`) |
|---|---|---|
| `FAL_KEY` presente | edit con `fal-ai/nano-banana-2/edit` ⭐ | text-to-image con `fal-ai/nano-banana-2` |
| `FAL_KEY` ausente | Paso 5 (error — configurar key) | Paso 5 (error — configurar key) |

---

### Paso 2 — Obtener descripción técnica del producto

Leer la ficha técnica aprobada por el usuario desde `product-info.json`:

```bash
cat .claude/brand-images/products/{PRODUCT_SLUG}/product-info.json 2>/dev/null
```

Extraer `technical_description` del JSON. Esta descripción fue generada y aprobada
por el usuario durante `/init` — es la fuente de verdad para describir el producto.

- **Si existe `technical_description`** → usar como `product_description`
- **Si no existe** (producto configurado antes de esta feature) → analizar
  `REF_IMAGE_PATH` con la herramienta de visión como fallback
- **Si `mode == "text-to-image"` y no hay producto** → `product_description = null`

---

### Paso 2A — Construir prompt para TEXT-TO-IMAGE (sin foto de referencia)

> Usar cuando `mode == "text-to-image"`.
> Genera un prompt que describe la escena completa desde cero.

> **🔒 REGLA CRÍTICA:** El prompt SIEMPRE se escribe en español, en primera persona,
> tono conversacional. NUNCA en inglés. NUNCA como instrucción técnica de stock photo.
> Debe sonar como si el dueño de la empresa le pidiera la imagen a un fotógrafo profesional.

#### Reglas críticas para text-to-image

| Regla | Correcto | Incorrecto |
|---|---|---|
| **Prompt en español, primera persona** | "Soy dueño de Sesgo Express, una fábrica de sesgo textil en Medellín..." | "Professional product photography, colorful rolls of bias binding tape..." (inglés genérico → el modelo inventa) |
| **Describir productos con detalle físico** | "un carrete cilíndrico de plástico negro con sesgo de color enrollado alrededor, y al lado varios discos planos apilados de sesgo predoblado en colores vivos" | "colorful rolls of bias binding tape in various widths and colors" (genérico → el modelo produce cintas de regalo o grosgrain) |
| **Composición explícita** | "muestre los dos productos juntos sobre fondo blanco: el carrete a la izquierda y los discos apilados a la derecha" | "neatly arranged on a wooden surface or industrial table" (vago → el modelo decide la composición) |
| **Usar el estilo visual de la marca** | "fotografía de producto profesional sobre fondo blanco limpio, colores vivos y saturados, estilo catálogo industrial textil" | "warm lighting, sharp focus, B2B industrial aesthetic" (genérico → parece foto de stock) |
| **Nombrar la empresa y ubicación** | "Soy dueño de Sesgo Express, en Medellín Colombia" | "Colombian textile factory setting" (el nombre se pierde, el modelo pone una fábrica de fondo) |
| **No describir acciones** | "herramientas de corte profesionales al lado del producto" | "muestra la tela siendo cortada" (acción → transforma el producto) |

#### Cadena de pensamiento para construir el prompt text-to-image

Antes de escribir el prompt, pensar en estos 7 pasos:

1. **¿Quién soy?** — Nombre de la empresa, sector, ubicación. Ser específico.
   "Soy dueño de {COMPANY_NAME}, una {INDUSTRY} en {LOCATION}."
2. **¿Qué producto(s)?** — Usar la `product_description` del producto.
   Describir CADA producto como se ve físicamente: forma, color, material, tamaño,
   presentación. Ejemplo: "carrete cilíndrico de plástico negro con sesgo de color
   enrollado alrededor" — NO "rollos de colores".
3. **¿Cuál es el tema del día?** — El tópico del post y cómo se refleja en la imagen.
4. **¿Cuál es el estilo visual de la marca?** — Usar `brand_style` si existe.
   Si no existe, usar por defecto: fotografía de producto profesional, fondo limpio.
5. **¿Qué composición tiene la imagen?** — Describir físicamente qué va dónde:
   qué producto va a la izquierda, qué va a la derecha, qué va al fondo,
   sobre qué superficie, con qué fondo. Ser explícito sobre la disposición espacial.
6. **¿Qué debe ser el protagonista?** — El producto siempre es el centro de atención.
   Los elementos decorativos y la ambientación acompañan, no compiten.
7. **¿Estilo fotográfico?** — Tipo de iluminación, enfoque, atmósfera. Concreto, no genérico.

#### Plantilla obligatoria para text-to-image

> **IMPORTANTE:** Seguir esta plantilla al pie de la letra. NO resumir. NO simplificar.
> NO convertir a estilo técnico. Cada sección debe estar presente en el prompt final.

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}
{Si hay LOCATION → agregar: en {LOCATION}}.
Necesito crear una imagen para publicar en redes sociales.

{Si hay PRODUCT_DESCRIPTION:
  Mi empresa fabrica/vende {PRODUCT_DESCRIPTION_DETALLADA}.
  → Describir CADA producto con su forma física exacta, color, material,
    presentación y tamaño relativo. Ej: "sesgo empitado: carrete cilíndrico
    de plástico negro con sesgo de color enrollado alrededor" — NO "rollos de colores".
}

{Si hay BRAND_STYLE:
  El estilo visual de mi marca es: {BRAND_STYLE}.
}

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: {TOPIC}.
{Si hay SPECIAL_DATE → agregar: La ocasión especial es {SPECIAL_DATE}.}

Crea una imagen atractiva para redes sociales que muestre {COMPOSICIÓN_EXPLÍCITA}.

{INSTRUCCIONES_DE_AMBIENTACIÓN}

El protagonista de la imagen debe ser {ELEMENTO_PROTAGONISTA_DEL_PRODUCTO}.
Todo lo demás en la imagen debe acompañar al producto sin opacarlo.

{CONTEXTO_DEL_TÓPICO_DEL_DÍA}

{ESTILO_FOTOGRÁFICO}.
Sin texto, sin logos, sin watermarks superpuestos.
```

**Construir `{COMPOSICIÓN_EXPLÍCITA}`:** Describir con precisión física qué contiene
la imagen y dónde va cada elemento. Esta es la parte más importante del prompt:
- Nombrar cada producto por su forma real (no términos genéricos del sector)
- Indicar posición: "a la izquierda", "al lado", "al fondo", "apilados a la derecha"
- Describir formas y colores específicos: "un carrete cilíndrico de plástico negro
  con sesgo azul enrollado" — NO "rollos de colores"
- Describir la superficie y fondo: "sobre fondo blanco limpio" o "sobre mesa de madera"
- Evitar: "productos variados", "elementos del sector", "neatly arranged"

#### Instrucciones de ambientación según el tópico (text-to-image)

| Tipo de tópico | Instrucciones de ambientación |
|---|---|
| Producto / servicio | "Quisiera que el producto esté sobre una superficie limpia y elegante, con fondo suave y difuminado, iluminación de estudio que resalte los detalles y la textura del producto. Algunos elementos del sector alrededor, ordenados y estéticos." |
| Tip del sector | "Quisiera que el producto esté sobre una mesa de trabajo profesional de {INDUSTRY}, con algunas herramientas del oficio al lado (ordenadas, no desordenadas). Fondo limpio que transmita profesionalismo." |
| Caso de éxito / cliente satisfecho | "Quisiera que el producto esté en un ambiente corporativo elegante, sobre una superficie de madera o mármol, con iluminación cálida que transmita confianza y calidad." |
| Detrás de escena / proceso | "Quisiera que el producto esté en un ambiente de taller o producción, pero ordenado y profesional. Elementos de manufactura al fondo, ligeramente desenfocados." |
| Tendencia / mercado | "Quisiera que el producto esté sobre una superficie minimalista, fondo con gradiente sutil. Composición editorial contemporánea." |
| Fecha especial | "Quisiera que el producto esté sobre una mesa con ambientación de {SPECIAL_DATE}: {DECORACIÓN_ACORDE}. El producto sigue siendo el protagonista absoluto." |
| Nuevo lanzamiento | "Quisiera que el producto esté sobre una superficie premium (mármol, madera oscura o acrílico), con fondo degradado limpio e iluminación lateral que destaque cada detalle." |

#### Ejemplo completo de prompt text-to-image

```
Soy dueño de Sesgo Express, una fábrica de sesgo textil en Medellín, Colombia.
Necesito crear una imagen para publicar en redes sociales.

Mi empresa fabrica sesgo textil: tiras de tela que se usan para ribetear
bordes de prendas de ropa. El sesgo planchado viene en discos planos de
tela doblada, enrollados en tortas de 50 metros, en muchos colores vivos
como rojo, azul, verde, amarillo, naranja, negro y blanco. Cada torta
viene envuelta en plástico transparente.

El estilo visual de mi marca es: fotografía de producto profesional,
colores vivos y saturados, sin personas, estilo catálogo industrial textil.

Me gustaría que generes una imagen profesional y realista para publicar en
los canales y redes sociales oficiales de la marca (Instagram, Facebook,
página web). La imagen debe verse como si hubiera sido tomada y ambientada
por un equipo experto en fotografía de producto.

El tema del post de hoy es: sesgo planchado para el Día de la Mujer.
La ocasión especial es el Día de la Mujer.

Crea una imagen atractiva para redes sociales que muestre varias tortas
de sesgo planchado apiladas y dispuestas sobre una mesa de madera cálida
y limpia, en diferentes colores vivos (rojo, rosa, blanco, lavanda).
Al fondo, flores de colores pastel suaves ligeramente desenfocadas
(rosas, blancas, lavanda), y una tela de algodón blanca o crema como
base decorativa. Composición limpia y acogedora.

El protagonista de la imagen deben ser las tortas de sesgo de colores.
Todo lo demás en la imagen debe acompañar al producto sin opacarlo.

La ambientación debe evocar el Día de la Mujer sin opacar al producto.
Tonos cálidos, rosados suaves y blancos. Atmósfera tierna.

Fotografía comercial de producto, iluminación natural cálida y suave,
enfoque nítido en las tortas de sesgo.
Sin texto, sin logos, sin watermarks superpuestos.
```

Usar el prompt construido como `{PROMPT_CONSTRUIDO}` → ir al **Paso 3A**.

---

### Paso 2B — Construir prompt para EDIT-IMAGE (con foto de referencia)

> Usar cuando `mode == "edit-image"`.
> Toma una foto casual/real del producto y la transforma en una imagen profesional
> lista para publicar en Instagram, redes sociales y página web.

> **🔒 REGLA CRÍTICA:** El prompt SIEMPRE se escribe en español, en primera persona,
> tono conversacional. NUNCA en inglés. NUNCA como instrucción técnica.
> Debe sonar como si el dueño de la empresa le pidiera a un diseñador que mejore su foto.

#### Reglas críticas para edit-image

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

#### Cadena de pensamiento para construir el prompt edit-image

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

#### Plantilla obligatoria para edit-image

> **IMPORTANTE:** Seguir esta plantilla al pie de la letra. NO resumir. NO simplificar.

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

#### Instrucciones de edición según el tópico (edit-image)

| Tipo de tópico | Instrucciones de edición |
|---|---|
| Producto / servicio | "Quisiera que el producto esté sobre una superficie limpia y elegante, que el fondo sea suave y difuminado, con iluminación de estudio que resalte los detalles y la textura del producto." |
| Tip del sector | "Quisiera que el producto esté sobre una mesa de trabajo profesional de {INDUSTRY}, con algunas herramientas del oficio al lado (ordenadas, no desordenadas). Fondo limpio." |
| Caso de éxito / cliente satisfecho | "Quisiera que el producto esté en un ambiente corporativo elegante, sobre una superficie de madera o mármol, con iluminación cálida que transmita confianza y calidad." |
| Detrás de escena / proceso | "Quisiera que el producto esté en un ambiente de taller o producción, pero ordenado y profesional. Elementos de manufactura al fondo, ligeramente desenfocados." |
| Tendencia / mercado | "Quisiera que el producto esté sobre una superficie minimalista, fondo con gradiente sutil. Composición editorial contemporánea." |
| Fecha especial | "Quisiera que el producto esté sobre una mesa con ambientación de {SPECIAL_DATE}: {DECORACIÓN_ACORDE}. El producto sigue siendo el protagonista absoluto." |
| Nuevo lanzamiento | "Quisiera que el producto esté sobre una superficie premium (mármol, madera oscura o acrílico), con fondo degradado limpio e iluminación lateral que destaque cada detalle." |

#### Ejemplo completo de prompt edit-image

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

Usar el prompt construido como `{PROMPT_CONSTRUIDO}` → ir al **Paso 3B**.

---

### Paso 2C — Negative prompt

Para `nano-banana-2`: generalmente no necesita negative prompt con prompts conversacionales.
Incluir solo si la primera generación tiene defectos visibles.

Negative prompt estándar (cuando se necesite):
```
text, watermark, logo, cartoon, illustration, low quality, blurry, deformed hands,
extra fingers, bad anatomy, AI artifacts
```

---

### Paso 3A — Text-to-Image con fal.ai nano-banana-2

> Usar cuando `mode == "text-to-image"` (no hay foto de referencia).

```bash
curl -s -X POST "https://fal.run/fal-ai/nano-banana-2" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"{PROMPT_CONSTRUIDO}\",
    \"image_size\": \"square_hd\",
    \"num_images\": 1,
    \"enable_safety_checker\": true
  }"
```

> **Para Facebook**: cambiar `"image_size"` a `"landscape_4_3"`

---

### Paso 3B — Edit Image con fal.ai nano-banana-2/edit ⭐

> Usar cuando `mode == "edit-image"` y hay `FAL_KEY`.
> Toma la foto de referencia del producto y la transforma según el prompt de edición,
> preservando el producto como protagonista y modificando el contexto/fondo/ambientación.

```bash
curl -s -X POST "https://fal.run/fal-ai/nano-banana-2/edit" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"image_url\": \"$IMAGE_DATA_URI\",
    \"prompt\": \"{PROMPT_CONSTRUIDO}\",
    \"image_size\": \"square_hd\",
    \"num_images\": 1,
    \"enable_safety_checker\": true
  }"
```

> **Para Facebook**: cambiar `"image_size"` a `"landscape_4_3"`

**Respuesta esperada (misma estructura que nano-banana-2):**
```json
{
  "images": [
    {
      "url": "https://fal.media/files/xxx/edited.jpeg",
      "width": 1024,
      "height": 1024,
      "content_type": "image/jpeg"
    }
  ],
  "seed": 12345,
  "has_nsfw_concepts": [false]
}
```

Extraer: `images[0].url` → URL pública persistente, lista para Instagram Graph API.

---

### Verificaciones comunes (aplica a Paso 3A y 3B)

**Si `has_nsfw_concepts[0]` es `true`** → regenerar (máximo 2 intentos).

**Verificación de calidad:** Revisar visualmente la imagen generada con la herramienta de visión.
Si hay defectos (manos deformes, caras, artefactos) → regenerar con variación del prompt. Máximo 3 intentos.

**Verificación de integridad — antes de continuar al Paso 4:**
- `image_url` debe ser una URL pública de fal.ai (`fal.media/...`), nunca una ruta local.
- Si `image_url` apunta a un archivo local o a `REF_IMAGE_PATH` → error: la generación no se completó. Reintentar.

---

### Paso 4 — Guardar resultado

```bash
mkdir -p .claude/posts/images
```

Crea `.claude/posts/images/{FECHA}.json`:
```json
{
  "date": "{FECHA_ISO}",
  "provider": "fal",
  "model": "fal-ai/nano-banana-2 | fal-ai/nano-banana-2/edit",
  "mode": "text-to-image | edit-image",
  "product_slug": "{SLUG_DEL_PRODUCTO} | null",
  "reference_image": ".claude/brand-images/products/{SLUG}/ref-1.jpg | null",
  "prompt_used": "{PROMPT_CONSTRUIDO}",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "topic": "{TOPIC_DEL_POST}",
  "category": "{CATEGORIA_DEL_POST}",
  "platform": "instagram"
}
```

> `mode`: `"edit-image"` (con foto de referencia) | `"text-to-image"` (sin referencia)
> Las URLs de fal.ai son persistentes (no expiran)

---

### Paso 5 — Si no hay FAL_KEY

```
⚠️  No se encontró FAL_KEY en las variables de entorno

La imagen del post NO puede ser la foto de referencia original.
Debes generar una imagen nueva antes de publicar.

Para continuar:

  Configura la variable de entorno: FAL_KEY=tu_key_aqui
  Obtener en: https://fal.ai → Dashboard → API Keys

⛔ NO publicar la foto de referencia original como imagen del post.
```

---

## Output del skill

```json
{
  "success": true,
  "provider": "fal",
  "mode": "text-to-image | edit-image",
  "model": "fal-ai/nano-banana-2 | fal-ai/nano-banana-2/edit",
  "product_slug": "{slug-del-producto} | null",
  "reference_image_used": ".claude/brand-images/products/{slug}/ref-1.jpg | null",
  "image_url": "https://fal.media/files/xxx/...",
  "prompt_used": "...",
  "dimensions": "1024x1024",
  "ready_for_instagram": true
}
```

---

## Precios de referencia

| Modelo | Modo | Precio/imagen | Velocidad | Recomendado para |
|---|---|---|---|---|
| fal-ai/nano-banana-2/edit | edit-image | ~$0.050 | ~10 seg | ⭐ Editar foto real del producto |
| fal-ai/nano-banana-2 | text-to-image | ~$0.025 | ~15 seg | Sin foto de referencia |

---

## Notas

- **edit-image es el modo preferido** cuando hay fotos de referencia: preserva el producto real y solo modifica el contexto/ambientación
- **text-to-image** se usa cuando no hay fotos de referencia o se necesita una imagen conceptual
- Configurar fotos de referencia ejecutando `/init` desde el proyecto de empresa
- Las fotos de referencia se leen de `.claude/brand-images/products/{slug}/` (max recomendado: 5 fotos por producto)
- Las URLs de fal.ai son persistentes (no expiran) — ideales para Instagram Graph API
- Si el post tiene fecha especial, incluirla en el prompt de edición para ambientar la imagen
- El prompt nunca debe pedir texto dentro de la imagen — Instagram lo procesa mejor sin texto
- Compatible con la Instagram Graph API: `image_url` se pasa directamente al crear el media container

## Guía anti-alucinaciones

| Problema común | Causa | Solución |
|---|---|---|
| Manos con 6+ dedos | Poco contexto anatómico + pocos pasos | Negative prompt + 28 pasos (flux/dev) |
| Caras con 3 ojos | Composición ambigua | Especificar "retrato de perfil" o evitar caras |
| Piel plástica / artificial | Modelo incorrecto | Usar prompts conversacionales con contexto real de la empresa |
| Texto ilegible en imagen | Modelos no generan texto bien | Nunca pedir texto en el prompt |
| Producto no se parece a la foto | Prompt de edición demasiado agresivo | Ser más específico en la instrucción, editar solo el contexto |
| Producto distorsionado | Imagen de referencia de baja resolución | Usar fotos de mínimo 512×512 px como referencia |
| Fondo no cambia lo suficiente | Instrucción de edición muy vaga | Ser específico: "cambiar fondo a X" en vez de "mejorar" |

**Regla de oro:** usar siempre **edit-image con foto de referencia** cuando sea posible.
El resultado es más profesional, más fiel a la marca y más rápido de aprobar internamente.
