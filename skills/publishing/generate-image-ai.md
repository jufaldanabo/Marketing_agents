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

> **🔒 REGLA FUNDAMENTAL — NO NEGOCIABLE:**
> Las fotos de referencia del producto son **solo input para la generación de IA**.
> La imagen que se publica en redes sociales es **SIEMPRE una imagen nueva generada por IA**,
> nunca la foto original. Si hay fotos de referencia disponibles → obligatoriamente img2img.
> Si no hay fotos → generar de texto. En ningún caso publicar una foto sin procesar.

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

- **Con imágenes** → `mode = "img2img"` (OBLIGATORIO) → continuar con 0.4
  > La foto de referencia es el input de la generación, no la imagen final.
  > `REF_IMAGE_PATH` se usa únicamente para pasar a la API. Nunca como `image_url` de publicación.
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
| `FAL_KEY` | img2img con `fal-ai/nano-banana-2` ⭐ | text-to-image con `fal-ai/nano-banana-2` |
| `OPENAI_API_KEY` | Describir referencia via visión → prompt DALL-E 3 | Prompt de texto estándar DALL-E 3 |
| ninguno | Paso 4 (prompt externo solamente) | Paso 4 (prompt externo solamente) |

---

### Paso 2 — Construir el prompt (delegado a `generate-image-prompt.md`)

La construcción del prompt se delega al skill `generate-image-prompt.md`, que es la
fuente única de verdad para la estructura conversacional, las plantillas por tópico
y la adaptación por herramienta.

#### 2.1 — Si hay foto de referencia: extraer descripción visual

**Solo cuando `mode == "img2img"`:** Analizar `REF_IMAGE_PATH` con la herramienta de visión
para extraer una descripción del producto:
- Qué tipo de producto/objeto se ve en la foto
- Colores reales presentes
- Cómo está presentado (forma, disposición)
- Material o acabado si es evidente

Guardar como `product_description` (string). Ejemplo:
`"tortas de sesgo planchado en colores vibrantes, presentadas como rollos planos apilados"`

**Si `mode == "text"`:** `product_description = null`

#### 2.2 — Ejecutar `generate-image-prompt.md`

Llamar al skill con estos inputs:

| Input | Valor |
|---|---|
| `topic` | `{TOPIC}` del post |
| `company_name` | `{COMPANY_NAME}` |
| `industry` | `{INDUSTRY}` |
| `product_description` | Descripción extraída de la foto (o null) |
| `brand_style` | Contenido de `brand-style.json` (o null) |
| `special_date` | `{SPECIAL_DATE}` (o null) |
| `tool` | `fal-ai` si hay `FAL_KEY`, `dalle` si hay `OPENAI_API_KEY`, `generic` si ninguno |
| `format` | `square` para Instagram, `landscape` para Facebook |

El skill devuelve:
```json
{
  "prompt": "Soy dueño de {COMPANY_NAME}...",
  "negative_prompt": "text, watermark, logo...",
  "ready_for_generate_image_ai": true
}
```

Usar `prompt` como `{PROMPT_CONVERSACIONAL_CONSTRUIDO}` en los pasos siguientes (2A y 2B).

#### 2.3 — Negative prompt

Usar el `negative_prompt` devuelto por `generate-image-prompt.md`.

Para `nano-banana-2`: generalmente no necesita negative prompt con prompts conversacionales.
Incluir solo si la primera generación tiene defectos visibles.

Para DALL-E 3 (no acepta negative_prompt separado): ya viene integrado en el prompt
por `generate-image-prompt.md` cuando `tool == "dalle"`.

---

### Paso 2A — Generar con fal.ai nano-banana-2

**Modelo único:** `fal-ai/nano-banana-2` — se usa para todos los casos (con y sin foto de referencia).

```bash
FAL_KEY=$(grep "^FAL_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
```

#### Con foto de referencia ⭐ PREFERIDO

Pasar la foto como `image_url` junto al prompt conversacional:

```bash
curl -s -X POST "https://fal.run/fal-ai/nano-banana-2" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"image_url\": \"$IMAGE_DATA_URI\",
    \"prompt\": \"{PROMPT_CONVERSACIONAL_CONSTRUIDO}\",
    \"strength\": 0.55,
    \"image_size\": \"square_hd\",
    \"num_images\": 1,
    \"enable_safety_checker\": true
  }"
```

> **`strength`** — cuánto se aleja la generación de la foto de referencia:
>
> | Tipo de producto | `strength` |
> |---|---|
> | Físico con forma definida (rollos, maquinaria, embalajes) | **0.50–0.60** |
> | Textura/patrón (telas, papeles, superficies) | **0.55–0.65** |
> | Consumo (alimentos, cosméticos, botellas) | **0.60–0.70** |
> | Servicios / conceptos abstractos | **0.70–0.80** |
>
> **Default**: `0.55`. Si el resultado no se parece a la foto → bajar a 0.45.
> Si es demasiado idéntico → subir a 0.65–0.70.

> **Para Facebook**: cambiar `"image_size"` a `"landscape_4_3"`

#### Sin foto de referencia

Solo prompt conversacional, sin `image_url`:

```bash
curl -s -X POST "https://fal.run/fal-ai/nano-banana-2" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"{PROMPT_CONVERSACIONAL_CONSTRUIDO}\",
    \"image_size\": \"square_hd\",
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

**Verificación de calidad:** Revisar visualmente la imagen generada con la herramienta de visión.
Si hay defectos (manos deformes, caras, artefactos) → regenerar con variación del prompt o ajustar `strength`. Máximo 3 intentos.

**Verificación de integridad — antes de continuar al Paso 3:**
- `image_url` debe ser una URL pública de IA (`fal.media/...` o `oaidalleapiprodscus...`), nunca una ruta local.
- Si `image_url` apunta a un archivo local o a `REF_IMAGE_PATH` → error: la generación no se completó. Reintentar o pasar a Paso 4.

---

### Paso 2B — Generar con DALL-E 3 (alternativa cuando no hay FAL_KEY)

> ⚠️ DALL-E 3 **no soporta img2img**. Cuando hay fotos de referencia, la descripción
> visual ya fue extraída en el Paso 2.1 y pasada a `generate-image-prompt.md` como
> `product_description`, por lo que el prompt ya la incorpora.

Usar el `{PROMPT_CONVERSACIONAL_CONSTRUIDO}` devuelto por `generate-image-prompt.md`
en el Paso 2.2 (ya adaptado para DALL-E cuando `tool == "dalle"`).

```bash
OPENAI_KEY=$(grep "^OPENAI_API_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

# DALL-E 3 — siempre "hd" para marketing
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "{PROMPT_CONVERSACIONAL_CONSTRUIDO}",
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

La imagen del post NO puede ser la foto de referencia original.
Debes generar una imagen nueva antes de publicar.

Opciones para continuar:

  Opción A — fal.ai (recomendado, soporta img2img desde tus fotos):
    Agrega al .env:  FAL_KEY=tu_key_aqui
    Obtener en: https://fal.ai → Dashboard → API Keys

  Opción B — DALL-E 3 (~$0.08/imagen, genera desde descripción de tu foto):
    Agrega al .env:  OPENAI_API_KEY=tu_key_aqui

  Opción C — Generación manual (sin API):
    Usa este prompt en Midjourney, Firefly, Adobe Express o Stable Diffusion:
    {PROMPT_CONSTRUIDO}
    Una vez generada, copia la URL pública de la imagen aquí para continuar.

⛔ NO publicar la foto de referencia original como imagen del post.
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
