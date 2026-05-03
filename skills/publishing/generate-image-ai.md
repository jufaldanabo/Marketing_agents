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
- `IMAGE_DATA_URI` → para llamada API en Paso 2A
- `mode = "edit-image"` → determina qué modelo y prompt usar

> Si hay `FAL_KEY`: usar `fal-ai/nano-banana-2/edit` con `image_url` + prompt de edición.
> Si solo hay `OPENAI_API_KEY`: analizar visualmente la referencia con la herramienta
> de visión para extraer descripción detallada → usarla como `product_description` en
> prompt text-to-image de DALL-E 3 (no soporta edit directo).

---

### Paso 1 — Detectar proveedor disponible

```bash
# Cargar .env si existe (local), en Railway las vars ya están en el entorno
[ -f .env ] && export $(grep -v '^#' .env | xargs)

# Verificar qué key está configurada
[ -n "$FAL_KEY" ] && echo "fal" || \
[ -n "$OPENAI_API_KEY" ] && echo "openai" || \
echo "none"
```

| Proveedor | Con imagen referencia (`edit-image`) | Sin imagen referencia (`text-to-image`) |
|---|---|---|
| `FAL_KEY` | edit con `fal-ai/nano-banana-2/edit` ⭐ | text-to-image con `fal-ai/nano-banana-2` |
| `OPENAI_API_KEY` | Describir referencia via visión → prompt text-to-image DALL-E 3 | Prompt de texto estándar DALL-E 3 |
| ninguno | Paso 4 (prompt externo solamente) | Paso 4 (prompt externo solamente) |

---

### Paso 2 — Construir el prompt (delegado a `generate-image-prompt.md`)

La construcción del prompt se delega al skill `generate-image-prompt.md`, que es la
fuente única de verdad para la estructura conversacional, las plantillas por tópico
y la adaptación por herramienta.

#### 2.1 — Obtener descripción técnica del producto

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

#### 2.2 — Ejecutar `generate-image-prompt.md`

Llamar al skill con estos inputs:

| Input | Valor |
|---|---|
| `mode` | `"edit-image"` si hay foto de referencia, `"text-to-image"` si no |
| `topic` | `{TOPIC}` del post |
| `company_name` | `{COMPANY_NAME}` |
| `industry` | `{INDUSTRY}` |
| `product_description` | `technical_description` del product-info.json (o null) |
| `brand_style` | Contenido de `brand-style.json` (o null) |
| `special_date` | `{SPECIAL_DATE}` (o null) |
| `tool` | `fal-ai` si hay `FAL_KEY`, `dalle` si hay `OPENAI_API_KEY`, `generic` si ninguno |
| `format` | `square` para Instagram, `landscape` para Facebook |

El skill devuelve:
```json
{
  "mode": "text-to-image | edit-image",
  "prompt": "Soy dueño de {COMPANY_NAME}... | Ambientar el producto con...",
  "negative_prompt": "text, watermark, logo...",
  "ready_for_generate_image_ai": true
}
```

Usar `prompt` como `{PROMPT_CONSTRUIDO}` en los pasos siguientes.
- Si `mode == "text-to-image"` → usar en **Paso 2A** (nano-banana-2 text-to-image)
- Si `mode == "edit-image"` → usar en **Paso 2C** (nano-banana-2/edit)

#### 2.3 — Negative prompt

Usar el `negative_prompt` devuelto por `generate-image-prompt.md`.

Para `nano-banana-2`: generalmente no necesita negative prompt con prompts conversacionales.
Incluir solo si la primera generación tiene defectos visibles.

Para DALL-E 3 (no acepta negative_prompt separado): ya viene integrado en el prompt
por `generate-image-prompt.md` cuando `tool == "dalle"`.

---

### Paso 2A — Text-to-Image con fal.ai nano-banana-2

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

### Paso 2B — Generar con DALL-E 3 (alternativa cuando no hay FAL_KEY)

> ⚠️ DALL-E 3 **no soporta edit-image directo**. Cuando hay fotos de referencia,
> la descripción visual ya fue extraída en el Paso 2.1 y pasada a
> `generate-image-prompt.md` como `product_description`. El skill genera un prompt
> text-to-image enriquecido con esa descripción (no un prompt de edición).

Usar el `{PROMPT_CONSTRUIDO}` devuelto por `generate-image-prompt.md`
en el Paso 2.2 (ya adaptado para DALL-E cuando `tool == "dalle"`).

```bash
# DALL-E 3 — siempre "hd" para marketing
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "{PROMPT_CONSTRUIDO}",
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

### Paso 2C — Edit Image con fal.ai nano-banana-2/edit ⭐

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

### Verificaciones comunes (aplica a Paso 2A, 2B y 2C)

**Si `has_nsfw_concepts[0]` es `true`** → regenerar (máximo 2 intentos).

**Verificación de calidad:** Revisar visualmente la imagen generada con la herramienta de visión.
Si hay defectos (manos deformes, caras, artefactos) → regenerar con variación del prompt. Máximo 3 intentos.

**Verificación de integridad — antes de continuar al Paso 3:**
- `image_url` debe ser una URL pública de IA (`fal.media/...` o `oaidalleapiprodscus...`), nunca una ruta local.
- Si `image_url` apunta a un archivo local o a `REF_IMAGE_PATH` → error: la generación no se completó. Reintentar o pasar a Paso 4.

---

### Paso 3 — Guardar resultado

```bash
mkdir -p .claude/posts/images
```

Crea `.claude/posts/images/{FECHA}.json`:
```json
{
  "date": "{FECHA_ISO}",
  "provider": "fal | openai",
  "model": "fal-ai/nano-banana-2 | fal-ai/nano-banana-2/edit | dall-e-3",
  "mode": "text-to-image | edit-image",
  "product_slug": "{SLUG_DEL_PRODUCTO} | null",
  "reference_image": ".claude/brand-images/products/{SLUG}/ref-1.jpg | null",
  "prompt_used": "{PROMPT_CONSTRUIDO}",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "topic": "{TOPIC_DEL_POST}",
  "category": "{CATEGORIA_DEL_POST}",
  "platform": "instagram",
  "expires_at": null
}
```

> `mode`: `"edit-image"` (con foto de referencia) | `"text-to-image"` (sin referencia)
> `expires_at`: null para fal.ai (URLs persistentes), timestamp ISO para DALL-E (+60min)

---

### Paso 4 — Si no hay API key disponible

```
⚠️  No se encontró FAL_KEY ni OPENAI_API_KEY en las variables de entorno

La imagen del post NO puede ser la foto de referencia original.
Debes generar una imagen nueva antes de publicar.

Opciones para continuar:

  Opción A — fal.ai (recomendado, soporta img2img desde tus fotos):
    Configura la variable de entorno: FAL_KEY=tu_key_aqui
    Obtener en: https://fal.ai → Dashboard → API Keys

  Opción B — DALL-E 3 (~$0.08/imagen, genera desde descripción de tu foto):
    Configura la variable de entorno: OPENAI_API_KEY=tu_key_aqui

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
  "mode": "text-to-image | edit-image",
  "model": "fal-ai/nano-banana-2 | fal-ai/nano-banana-2/edit | dall-e-3",
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
| fal.ai | FLUX Pro edit | edit-image | ~$0.050 | ~10 seg | ⭐ Editar foto real del producto |
| fal.ai | nano-banana-2 | text-to-image | ~$0.025 | ~15 seg | Sin foto de referencia |
| fal.ai | FLUX Schnell (8 pasos) | text-to-image | ~$0.003 | ~3 seg | Solo producto/objeto, sin personas |
| OpenAI | DALL-E 3 HD | text-to-image | ~$0.080 | ~15 seg | Alternativa cuando no hay FAL_KEY |
| OpenAI | DALL-E 3 Standard | text-to-image | ~$0.040 | ~10 seg | No recomendado — usar HD |

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
| Piel plástica / artificial | Modelo incorrecto | Usar `style: "natural"` en DALL-E; flux/dev en fal.ai |
| Texto ilegible en imagen | Modelos no generan texto bien | Nunca pedir texto en el prompt |
| Producto no se parece a la foto | Prompt de edición demasiado agresivo | Ser más específico en la instrucción, editar solo el contexto |
| Producto distorsionado | Imagen de referencia de baja resolución | Usar fotos de mínimo 512×512 px como referencia |
| Fondo no cambia lo suficiente | Instrucción de edición muy vaga | Ser específico: "cambiar fondo a X" en vez de "mejorar" |

**Regla de oro:** usar siempre **edit-image con foto de referencia** cuando sea posible.
El resultado es más profesional, más fiel a la marca y más rápido de aprobar internamente.
