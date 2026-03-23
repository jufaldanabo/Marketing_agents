# Skill: generate-image-ai

Genera una imagen publicitaria B2B usando IA (fal.ai FLUX o DALL-E 3) a partir de las
fotos de referencia del producto, el estilo visual de la marca y el contexto del post del día.

El modo principal es **imagen a imagen (img2img)**: toma una foto real del producto como
base y la recrea ambientada en un nuevo contexto (mesa de trabajo, sala de reuniones,
entorno industrial, personas al fondo), generando imágenes de IA que parecen fotografías
comerciales profesionales del producto real.

Devuelve una **URL pública** lista para usar directamente en Instagram Graph API.

---

## Variables requeridas

| Variable | Descripción |
|---|---|
| `FAL_KEY` | API key de fal.ai — requerida para img2img y text-to-image |
| `OPENAI_API_KEY` | Alternativa sin FAL_KEY — DALL-E 3 solo texto (no soporta img2img) |

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

**Ejemplos:**
```
topic: "cómo elegir el producto correcto para tu proyecto"
keywords del producto: ["tornillo", "fijación", "acero", "hardware"]
→ coincidencia alta → product_slug: "tornillo-acero" ✓

topic: "beneficios del producto premium"
keywords del producto: ["premium", "calidad"]
→ coincidencia media → product_slug: "linea-premium" ✓

topic: "tendencias del mercado 2026"
ninguna coincidencia específica → usar default_product ✓
```

#### 0.3 — Verificar si hay imágenes de referencia

```bash
PRODUCT_SLUG="{SLUG_SELECCIONADO}"
ls .claude/brand-images/products/$PRODUCT_SLUG/ 2>/dev/null | grep -E "\.(jpg|jpeg|png|webp)$"
```

- **Con imágenes** → `mode = "img2img"` → continuar con 0.4
- **Sin imágenes** → `mode = "text"` → saltar al Paso 1

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
- `IMAGE_DATA_URI` → para llamada API en Paso 2A
- `mode = "img2img"` → determina qué variante usar en Paso 2A

> Si hay `FAL_KEY`: usar img2img directo con `IMAGE_DATA_URI`.
> Si solo hay `OPENAI_API_KEY`: analizar visualmente la referencia con la herramienta
> de visión para extraer descripción detallada → usarla en el prompt de DALL-E 3.

---

### Paso 1 — Detectar proveedor disponible

```bash
# Verificar qué key está configurada
grep -E "^FAL_KEY=.+" .env 2>/dev/null && echo "fal" || \
grep -E "^OPENAI_API_KEY=.+" .env 2>/dev/null && echo "openai" || \
echo "none"
```

| Proveedor | Con imagen referencia | Sin imagen referencia |
|---|---|---|
| `FAL_KEY` | img2img con `flux/dev/image-to-image` ⭐ | text-to-image con `flux/dev` o `schnell` |
| `OPENAI_API_KEY` | Describir referencia via visión → prompt DALL-E 3 | Prompt de texto estándar DALL-E 3 |
| ninguno | Paso 4 (prompt externo solamente) | Paso 4 (prompt externo solamente) |

---

### Paso 2 — Construir el prompt

El prompt varía según el modo detectado en Paso 0.

#### Modo img2img (hay foto de referencia + FAL_KEY)

En img2img el modelo usa la foto como base visual, pero **el prompt ancla el producto**
para que el modelo sepa qué está generando. Sin un ancla de producto, el modelo lo
reinterpreta libremente y el resultado no se parece al original.

**Estructura del prompt img2img — SIEMPRE en dos bloques:**
```
{BLOQUE 1 — descripción del producto}: {tipo}, {colores visibles}, {forma/presentación}
{BLOQUE 2 — contexto/ambiente}: {superficie_o_entorno}, {elementos_contextuales}, {iluminacion}, {mood}
{anclas_fotorrealismo}
```

**Bloque 1 — cómo describir el producto (OBLIGATORIO):**

Analizar visualmente la imagen de referencia con la herramienta de visión y extraer:
- **Tipo de objeto**: lo que realmente se ve en la foto — inferir sin asumir
- **Colores visibles**: los colores reales presentes en la imagen
- **Forma/presentación**: cómo está dispuesto en la foto (apilado, en fila, en expositor, etc.)
- **Material** (solo si es claramente visible): no inventar si no es evidente

**Ejemplos de descripciones por industria:**
```
Manufactura/industrial: "sacos de cemento de 50kg apilados en pallet, color gris claro, impresos con logo"
Alimentos: "frascos de vidrio transparente con producto en polvo naranja, tapas metálicas doradas, en fila"
Tecnología: "dispositivo electrónico rectangular negro con pantalla LED frontal y botones laterales"
Construcción: "tubos de PVC blanco de distintos diámetros, apilados horizontalmente en almacén"
Servicios: "profesional en traje azul marino, de perfil, con documentos en mano"
Agro/campo: "bolsas de semillas de 10kg apiladas, etiquetas verdes con texto, sobre superficie de madera"
```

| ✅ SÍ incluir en el prompt img2img | ❌ NO inventar ni exagerar |
|---|---|
| Tipo de producto extraído de la referencia | Colores que no aparecen en la foto real |
| Colores reales observados en la imagen | Materiales no visibles claramente |
| Forma y presentación tal como se ve | Detalles de producto que no son evidentes |
| Contexto y ambiente según el tópico | Texturas o acabados que no son distinguibles |

**Bloque 2 — adaptar el contexto al tópico del post:**
- "tip del sector" → sobre mesa de trabajo de madera, muestras y cuaderno al lado, luz natural
- "caso de éxito" → primer plano destacado, personas de traje al fondo desenfocadas
- "detrás de escena" → en proceso de producción, entorno industrial limpio y ordenado
- "tendencia de mercado" → superficie moderna, composición editorial, elementos de diseño
- "fecha especial" → decoración acorde a la fecha, ambiente festivo o emotivo
- "nuevo lanzamiento" → fondo minimalista blanco, estudio de fotografía, iluminación de producto

**Estructura del prompt final (aplicable a cualquier industria):**
```
{descripción del producto extraída de la referencia},
{contexto/entorno según el tópico},
{iluminación y ambiente},
{personas si aplica — de espaldas o perfil},
fotografía real, hiperrealista, fotografía comercial profesional, resolución 8K,
nitidez perfecta, iluminación natural, sin distorsiones, sin artefactos de IA
```

**Ejemplos multi-industria:**

*Manufactura — tip de producción:*
```
sacos de cemento gris claro de 50kg con logo impreso, apilados en pallet de madera,
en nave industrial ordenada con iluminación cenital, operario con casco amarillo
de espaldas supervisando al fondo (desenfocado), fotografía industrial profesional...
```

*Alimentos — lanzamiento de producto:*
```
frascos de vidrio transparente con miel artesanal dorada y tapas metálicas, en fila sobre
tabla de madera rústica con flores silvestres al lado, luz natural cálida de ventana,
ambiente de cocina gourmet, fotografía comercial de alimentos, hiperrealista...
```

*Tecnología — caso de éxito:*
```
dispositivo electrónico negro rectangular con pantalla LED encendida, sobre escritorio de
oficina moderno, laptop y smartphone al fondo desenfocados, luz de estudio fría y nítida,
ambiente corporativo premium, fotografía de producto tecnológico profesional...
```

#### Modo texto (sin foto de referencia, o OPENAI_API_KEY sin referencia)

Usar el flujo clásico de descripción completa del producto:

**Estructura del prompt texto:**
```
{estilo_fotografico}, {mood}, colores dominantes {palette},
{descripcion_visual_completa_del_producto_y_contexto},
{sector_industrial}, {anclas_fotorrealismo}
```

**Reglas:**
1. **Si existe `brand_style`** → usar `photography_style`, `mood`, `color_palette`, `elements`
2. **Si NO existe `brand_style`** → construir prompt limpio basado en industria + tópico
3. **Prioridad de composición** (evitar defectos anatómicos):
   - Primera opción: producto/objeto/entorno sin personas
   - Segunda opción: personas de espaldas, de perfil, o plano detalle (manos, etc.)
   - Tercera opción: personas de frente (solo si la categoría lo requiere)

#### Modo texto con referencia (OPENAI_API_KEY + hay foto)

1. Analizar la imagen de referencia con la herramienta de visión
2. Extraer descripción visual detallada: colores, textura, material, forma, acabados
3. Incorporar esa descripción como primer bloque del prompt:
```
{descripcion_visual_extraida_de_foto_real}, ambientado en {contexto_segun_topico},
{iluminacion_y_entorno_profesional}, {anclas_fotorrealismo}, RESTRICTIONS: ...
```

**Anclas de fotorrealismo — SIEMPRE agregar al final del prompt (todos los modos):**
```
fotografía real, hiperrealista, fotografía comercial profesional,
resolución 8K, nitidez perfecta, iluminación de estudio natural,
proporciones anatómicas correctas, manos con cinco dedos,
rasgos faciales naturales, sin distorsiones, sin artefactos de IA
```

**Para Instagram**: `square_hd` (1024×1024)
**Para Facebook**: `landscape_4_3` (1280×960)

---

### Paso 2.1 — Negative prompt (SIEMPRE incluir)

**Negative prompt estándar — copiar en cada llamada a fal.ai:**
```
cartoon, illustration, painting, drawing, anime, sketch, CGI, 3D render,
unrealistic, surreal, abstract art, watercolor, oil painting,
deformed hands, extra fingers, six fingers, 6 fingers, missing fingers, fused fingers,
extra thumbs, malformed hands, extra limbs, extra arms, extra legs,
disfigured face, deformed face, distorted face, asymmetrical face,
extra eyes, three eyes, cyclops, two mouths, extra mouths, extra lips, melted face,
bad anatomy, bad proportions, incorrect anatomy, mutation, mutated body,
cloned faces, duplicate features, body horror, gross proportions,
blurry, pixelated, low quality, low resolution, jpeg artifacts, noise,
watermark, text overlay, signature, username, logo on image,
AI artifacts, bad art, worst quality, out of frame, cropped badly,
plastic skin, wax skin, unnatural skin texture, toy-like appearance
```

**Para DALL-E 3** (no acepta negative_prompt separado): agregar al final del prompt positivo:
```
-- IMPORTANT: photorealistic commercial photography only, no illustration, no cartoon,
no extra fingers (exactly 5 fingers per hand), no extra eyes, no facial deformities,
no AI artifacts, anatomically perfect human proportions --
```

---

### Paso 2A — Generar con fal.ai FLUX

#### Modo img2img — con foto de referencia del producto ⭐ PREFERIDO

**Modelo:** `fal-ai/flux/dev/image-to-image`

```bash
FAL_KEY=$(grep "^FAL_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

NEGATIVE_PROMPT="cartoon, illustration, painting, drawing, anime, sketch, CGI, 3D render, unrealistic, surreal, abstract art, watercolor, deformed hands, extra fingers, six fingers, 6 fingers, missing fingers, fused fingers, extra thumbs, malformed hands, extra limbs, extra arms, extra legs, disfigured face, deformed face, distorted face, asymmetrical face, extra eyes, three eyes, cyclops, two mouths, extra mouths, extra lips, melted face, bad anatomy, bad proportions, incorrect anatomy, mutation, mutated body, cloned faces, duplicate features, body horror, gross proportions, blurry, pixelated, low quality, watermark, text overlay, signature, logo on image, AI artifacts, bad art, worst quality, plastic skin, wax skin, unnatural skin texture, toy-like appearance"

# IMG2IMG — product reference + ambient context
curl -s -X POST "https://fal.run/fal-ai/flux/dev/image-to-image" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"image_url\": \"$IMAGE_DATA_URI\",
    \"prompt\": \"{PROMPT_DE_CONTEXTO_CONSTRUIDO}\",
    \"negative_prompt\": \"$NEGATIVE_PROMPT\",
    \"strength\": 0.55,
    \"num_inference_steps\": 28,
    \"guidance_scale\": 3.5,
    \"image_size\": \"square_hd\",
    \"num_images\": 1,
    \"enable_safety_checker\": true
  }"
```

> **`strength`** controla cuánto se aleja el modelo de la imagen de referencia.
> Calibrar según el tipo de producto:
>
> | Tipo de producto | `strength` recomendado | Por qué |
> |---|---|---|
> | Producto físico con forma definida (rollos, maquinaria, prendas, embalajes) | **0.50–0.60** | El modelo debe preservar la forma y colores exactos |
> | Producto con textura/patrón (telas, papeles, superficies) | **0.55–0.65** | Balance entre fidelidad y ambientación |
> | Producto de consumo (alimentos, cosméticos, botellas) | **0.60–0.70** | Forma reconocible, más libertad de escena |
> | Servicios o conceptos (sin producto físico claro) | **0.70–0.80** | Mayor creatividad, menos literalidad |
>
> **Valor por defecto**: `0.55` — seguro para la mayoría de productos físicos B2B.
> Si el producto generado **no se parece a la referencia** → bajar a 0.45–0.50.
> Si el resultado es **demasiado idéntico a la foto** → subir a 0.65–0.70.

> **Para Facebook**: cambiar `"image_size"` a `"landscape_4_3"` (1280×960)

#### Modo texto — sin foto de referencia

**Con personas:** `fal-ai/flux/dev` (28 pasos)
**Solo producto/objeto:** `fal-ai/flux/schnell` (8 pasos, más rápido y económico)

```bash
# Con personas — flux/dev, 28 pasos para mayor calidad anatómica
curl -s -X POST "https://fal.run/fal-ai/flux/dev" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"{PROMPT_POSITIVO_CONSTRUIDO}\",
    \"negative_prompt\": \"$NEGATIVE_PROMPT\",
    \"image_size\": \"square_hd\",
    \"num_inference_steps\": 28,
    \"guidance_scale\": 3.5,
    \"num_images\": 1,
    \"enable_safety_checker\": true
  }"

# Solo producto/objeto, sin personas — flux/schnell, 8 pasos
curl -s -X POST "https://fal.run/fal-ai/flux/schnell" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"{PROMPT_POSITIVO_CONSTRUIDO}\",
    \"negative_prompt\": \"$NEGATIVE_PROMPT\",
    \"image_size\": \"square_hd\",
    \"num_inference_steps\": 8,
    \"num_images\": 1,
    \"enable_safety_checker\": true
  }"
```

**Respuesta esperada (todos los modelos fal.ai):**
```json
{
  "images": [
    {
      "url": "https://fal.media/files/xxx/generated.jpeg",
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

**Si `has_nsfw_concepts[0]` es `true`** → regenerar (máximo 2 intentos).

**Verificación de calidad:** Revisar visualmente la imagen con la herramienta de visión.
Si hay defectos (manos deformes, caras, artefactos) → regenerar con variación del prompt o ajustar `strength`. Máximo 3 intentos.

---

### Paso 2B — Generar con DALL-E 3 (alternativa cuando no hay FAL_KEY)

> ⚠️ DALL-E 3 **no soporta img2img**. Cuando hay fotos de referencia, se usa la visión
> de Claude para describir el producto detalladamente e incorporar esa descripción en el prompt.

#### Con imagen de referencia del producto

1. Analizar `REF_IMAGE_PATH` con la herramienta de visión
2. Extraer descripción visual: colores exactos, textura, material, forma, acabados, proporciones
3. Construir el prompt combinando la descripción extraída + contexto ambiental del tópico:

```
{descripcion_visual_extraida_de_la_foto_real},
ambientado en {contexto_segun_topico}, {iluminacion_y_entorno},
{sector_industrial_si_aplica},
RESTRICTIONS: photorealistic commercial photography only, absolutely no cartoon or
illustration style, no extra fingers (exactly 5 fingers per hand, no more, no less),
no extra eyes or facial features, no deformed faces, no extra limbs, no body mutations,
no AI-generated artifacts, no text or watermarks overlaid on image,
anatomically perfect and natural human proportions if humans appear,
high resolution, sharp focus, professional studio lighting
```

#### Sin imagen de referencia

Usar prompt de texto estándar con el bloque RESTRICTIONS al final.

```bash
OPENAI_KEY=$(grep "^OPENAI_API_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

# DALL-E 3 — siempre "hd" para marketing
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "{PROMPT_CON_RESTRICCIONES}",
    "size": "1024x1024",
    "quality": "hd",
    "style": "natural",
    "n": 1
  }'
```

> Usar `"quality": "hd"` (no "standard") — doble detalle, menos defectos anatómicos.
> Precio: $0.080 vs $0.040 por imagen.

**Respuesta esperada:**
```json
{
  "data": [
    {
      "url": "https://oaidalleapiprodscus.blob.core.windows.net/private/...",
      "revised_prompt": "..."
    }
  ]
}
```

Extraer: `data[0].url`

> ⚠️ Las URLs de DALL-E expiran en ~60 minutos. Publicar en Instagram inmediatamente.
> Guardar `revised_prompt` por si hay que regenerar.

---

### Paso 3 — Guardar resultado

```bash
mkdir -p .claude/posts/images
```

Crea `.claude/posts/images/{FECHA}.json`:
```json
{
  "date": "{FECHA_ISO}",
  "provider": "fal",
  "model": "flux/dev/image-to-image",
  "mode": "img2img",
  "product_slug": "{SLUG_DEL_PRODUCTO}",
  "reference_image": ".claude/brand-images/products/{SLUG_DEL_PRODUCTO}/ref-1.jpg",
  "strength": 0.55,
  "prompt_used": "{descripción del producto extraída de la referencia}, sobre {contexto}...",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "topic": "{TOPIC_DEL_POST}",
  "category": "{CATEGORIA_DEL_POST}",
  "platform": "instagram",
  "expires_at": null
}
```

> `mode`: `"img2img"` (con foto de referencia) | `"text"` (sin referencia)
> `expires_at`: null para fal.ai (URLs persistentes), timestamp ISO para DALL-E (+60min)

---

### Paso 4 — Si no hay API key disponible

```
⚠️  No se encontró FAL_KEY ni OPENAI_API_KEY en .env

Para generar imágenes automáticamente, agrega una de estas variables:

  Opción A — fal.ai (recomendado, soporta img2img desde fotos de tus productos):
    FAL_KEY=tu_key_aqui
    Obtener en: https://fal.ai → Dashboard → API Keys

  Opción B — DALL-E 3 (~$0.08/imagen, solo texto):
    OPENAI_API_KEY=tu_key_aqui

Mientras tanto, puedes usar este prompt en Midjourney, Firefly o Stable Diffusion:
{PROMPT_CONSTRUIDO}
```

---

## Output del skill

```json
{
  "success": true,
  "provider": "fal | openai | none",
  "mode": "img2img | text",
  "product_slug": "{slug-del-producto} | null",
  "reference_image_used": ".claude/brand-images/products/{slug}/ref-1.jpg | null",
  "image_url": "https://...",
  "prompt_used": "...",
  "dimensions": "1024x1024",
  "ready_for_instagram": true
}
```

---

## Precios de referencia

| Proveedor | Modelo | Modo | Precio/imagen | Velocidad | Recomendado para |
|---|---|---|---|---|---|
| fal.ai | FLUX Dev img2img (28 pasos) | img2img | ~$0.025 | ~15 seg | ⭐ Con fotos reales del producto |
| fal.ai | FLUX Dev (28 pasos) | texto | ~$0.025 | ~15 seg | Con personas, sin foto de referencia |
| fal.ai | FLUX Schnell (8 pasos) | texto | ~$0.003 | ~3 seg | Solo producto/objeto, sin personas |
| OpenAI | DALL-E 3 HD | texto | ~$0.080 | ~15 seg | Alternativa cuando no hay FAL_KEY |
| OpenAI | DALL-E 3 Standard | texto | ~$0.040 | ~10 seg | No recomendado — usar HD |

---

## Notas

- **img2img es el modo preferido**: produce resultados más consistentes con la identidad visual real del producto
- **El prompt img2img SIEMPRE debe describir el producto primero** (tipo + colores + forma), luego el contexto/ambiente
- **`strength: 0.55`** es el punto de partida seguro para productos físicos B2B — preserva forma y colores, crea escena nueva
- Configurar fotos de referencia ejecutando `/init` desde el proyecto de empresa
- Las fotos de referencia se leen de `.claude/brand-images/products/{slug}/` (max recomendado: 5 fotos por producto)
- Las URLs de fal.ai son persistentes (no expiran) — ideales para Instagram Graph API
- Si el post tiene fecha especial, incluirla en el contexto ambiental del prompt img2img
- El prompt nunca debe pedir texto dentro de la imagen — Instagram lo procesa mejor sin texto
- Compatible con la Instagram Graph API: `image_url` se pasa directamente al crear el media container

## Guía anti-alucinaciones

| Problema común | Causa | Solución |
|---|---|---|
| Manos con 6+ dedos | Poco contexto anatómico + pocos pasos | Negative prompt + 28 pasos (flux/dev) |
| Caras con 3 ojos | Composición ambigua | Especificar "retrato de perfil" o evitar caras |
| Dos bocas / labios extra | Prompt sin anclaje realista | Usar "fotografía real" + anclas fotorrealismo |
| Piel plástica / artificial | Modelo incorrecto | Usar `style: "natural"` en DALL-E; flux/dev en fal.ai |
| Artefactos y ruido | Pocos pasos de inferencia | Mínimo 28 pasos con personas; 8 para producto |
| Texto ilegible en imagen | Modelos no generan texto bien | Nunca pedir texto en el prompt |
| Personas duplicadas | Prompt vago | Especificar cantidad exacta ("una persona", "dos personas") |
| Producto generado no se parece a la referencia | `strength` muy alto O prompt sin ancla de producto | Bajar a 0.45-0.50 Y agregar descripción del producto al inicio del prompt |
| Producto idéntico a la foto, sin recontextualización | `strength` muy bajo | Subir a 0.65-0.70 en img2img |
| Producto distorsionado | Imagen de referencia de baja resolución | Usar fotos de mínimo 512×512 px como referencia |

**Regla de oro:** usar siempre **img2img con foto de referencia** cuando sea posible.
El resultado es más profesional, más fiel a la marca y más rápido de aprobar internamente.
