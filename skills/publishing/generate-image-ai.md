# Skill: generate-image-ai

Genera una imagen publicitaria B2B usando IA (fal.ai FLUX o DALL-E 3) a partir del
estilo visual de la marca y el contexto del post del día.

Devuelve una **URL pública** lista para usar directamente en Instagram Graph API.

---

## Variables requeridas

| Variable | Descripción |
|---|---|
| `FAL_KEY` | API key de fal.ai — proveedor principal (rápido y económico) |
| `OPENAI_API_KEY` | Alternativa si no hay FAL_KEY — usa DALL-E 3 |

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
```

---

## Instrucciones para Claude

### Paso 1 — Detectar proveedor disponible

Lee `.env` (o las variables de entorno) para detectar cuál API key está disponible:

```bash
# Verificar qué key está configurada
grep -E "^FAL_KEY=.+" .env 2>/dev/null && echo "fal" || \
grep -E "^OPENAI_API_KEY=.+" .env 2>/dev/null && echo "openai" || \
echo "none"
```

- Si hay `FAL_KEY` → usar **fal.ai FLUX** (Paso 2A)
- Si hay `OPENAI_API_KEY` → usar **DALL-E 3** (Paso 2B)
- Si no hay ninguna → Paso 4 (solo prompt externo)

---

### Paso 2 — Construir el prompt positivo

Combina el estilo de marca + tópico + anclajes de fotorrealismo.

**Estructura del prompt:**
```
{estilo_fotografico}, {mood}, colores dominantes {palette}, {descripcion_visual_del_topico},
{sector_industrial}, {anclas_fotorrealismo}
```

**Reglas de construcción:**

1. **Si existe `brand_style`** → úsalo como base:
   - `photography_style` → define el tipo de imagen (producto, lifestyle, abstracto, etc.)
   - `mood` → tono emocional (profesional, cálido, innovador, etc.)
   - `color_palette` → mencionar los colores hex o sus equivalentes descriptivos
   - `elements` → incluir elementos recurrentes de la marca si son visuales

2. **Si NO existe `brand_style`** → generar un prompt limpio y profesional basado en
   el sector de la empresa y el tópico del post.

3. **Prioridad de tipo de imagen — evitar problemas anatómicos:**
   - **Primera opción**: fotografía de **producto, objeto o entorno** sin personas
     → eliminates el 100% de los problemas de manos, dedos y caras
   - **Segunda opción**: personas **de espaldas, de perfil, o en plano detalle** (manos con objeto,
     escritorio con computadora, etc.) → reduce drásticamente los defectos
   - **Tercera opción**: personas de frente → solo si la categoría lo requiere (ej. "caso de éxito",
     "equipo"). En ese caso agregar explícitamente los anclas anatómicos del punto 5.

4. **Adaptar el tópico al visual:**
   - "tips de reducción de desperdicios" → maquinaria limpia, proceso ordenado, sin personas
   - "caso de éxito" → apretón de manos (plano medio), o producto destacado con cliente de fondo
   - "tendencia de mercado" → imagen de sala de reunión, datos en pantalla, sin primer plano facial
   - "detrás de escena" → proceso industrial, herramientas, materiales
   - "Día Internacional de la Mujer" → mujer profesional de perfil o de espaldas en entorno laboral

5. **Anclas de fotorrealismo — SIEMPRE agregar al final del prompt positivo:**
   ```
   fotografía real, hiperrealista, fotografía comercial profesional,
   resolución 8K, nitidez perfecta, iluminación de estudio natural,
   proporciones anatómicas correctas, manos con cinco dedos,
   rasgos faciales naturales, sin distorsiones, sin artefactos de IA
   ```

6. **Para Instagram**: especificar `square_hd` (1024×1024)
   **Para Facebook**: especificar `landscape_4_3` (1280×960)

**Ejemplo de prompt resultante (producto, sin personas):**
```
fotografía de producto industrial sobre fondo blanco neutro, ambiente limpio y minimalista,
tonos cálidos beige y azul oscuro corporativo, maquinaria textil de precisión con
detalles técnicos visibles, sector manufactura, fotografía real, hiperrealista,
fotografía comercial profesional, resolución 8K, nitidez perfecta,
iluminación de estudio natural, sin distorsiones, sin artefactos de IA
```

**Ejemplo de prompt resultante (persona, plano detalle):**
```
manos de ejecutivo firmando documento sobre escritorio de madera oscura,
ambiente corporativo formal, luz de ventana lateral, tonos azul y beige,
fotografía real, hiperrealista, fotografía comercial profesional,
resolución 8K, proporciones anatómicas correctas, manos con cinco dedos,
sin distorsiones, sin artefactos de IA
```

---

### Paso 2.1 — Negative prompt (SIEMPRE incluir)

El negative prompt le dice a la IA qué **NO generar**. Es tan importante como el prompt positivo.
Se envía en el campo `negative_prompt` de la API (fal.ai) o embebido en el prompt (DALL-E 3).

**Negative prompt estándar — copiar en cada llamada:**
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

**Modelo recomendado:** `fal-ai/flux/dev` (soporta negative_prompt y más pasos → mayor calidad y
menos alucinaciones anatómicas, ~$0.025/imagen)

> ⚠️ No usar `flux/schnell` para imágenes con personas: tiene muy pocos pasos de inferencia
> (4 por defecto) y genera manos/caras defectuosas con frecuencia. Para imágenes de producto
> sin personas, schnell sí es suficiente.

```bash
FAL_KEY=$(grep "^FAL_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

NEGATIVE_PROMPT="cartoon, illustration, painting, drawing, anime, sketch, CGI, 3D render, unrealistic, surreal, abstract art, watercolor, deformed hands, extra fingers, six fingers, 6 fingers, missing fingers, fused fingers, extra thumbs, malformed hands, extra limbs, extra arms, extra legs, disfigured face, deformed face, distorted face, asymmetrical face, extra eyes, three eyes, cyclops, two mouths, extra mouths, extra lips, melted face, bad anatomy, bad proportions, incorrect anatomy, mutation, mutated body, cloned faces, duplicate features, body horror, gross proportions, blurry, pixelated, low quality, watermark, text overlay, signature, logo on image, AI artifacts, bad art, worst quality, plastic skin, wax skin, unnatural skin texture, toy-like appearance"

# Para Instagram (cuadrado) — imagen con personas
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

# Para Instagram (cuadrado) — solo producto/objeto, sin personas
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

> `num_inference_steps`: más pasos = más calidad y menos defectos anatómicos.
> Mínimo recomendado con personas: **28 pasos** (flux/dev).
> Para producto sin personas: **8 pasos** (flux/schnell) es suficiente.

**Respuesta esperada:**
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

**Verificación de calidad antes de publicar:** Revisar visualmente la imagen generada
con la herramienta de visión. Si se detectan manos con más de 5 dedos, caras deformadas
o artefactos evidentes → regenerar con una variación del prompt (agregar más contexto
fotográfico, cambiar composición). Máximo 3 intentos.

---

### Paso 2B — Generar con DALL-E 3 (alternativa)

DALL-E 3 no acepta `negative_prompt` como campo separado. Las restricciones anatómicas
se embeben directamente en el prompt positivo usando el bloque `RESTRICTIONS`.

**Prompt final para DALL-E 3** = `{PROMPT_POSITIVO}` + bloque de restricciones:

```
{PROMPT_POSITIVO_CONSTRUIDO}

RESTRICTIONS: photorealistic commercial photography only, absolutely no cartoon or
illustration style, no extra fingers (exactly 5 fingers per hand, no more, no less),
no extra eyes or facial features, no deformed faces, no extra limbs, no body mutations,
no AI-generated artifacts, no text or watermarks overlaid on image,
anatomically perfect and natural human proportions if humans appear,
high resolution, sharp focus, professional studio lighting
```

```bash
OPENAI_KEY=$(grep "^OPENAI_API_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

# DALL-E 3 siempre usar "hd" quality para marketing — reduce artefactos vs "standard"
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

> Usar `"quality": "hd"` (no "standard") — genera el doble de detalle y reduce
> significativamente los defectos anatómicos. Precio: $0.080 vs $0.040 por imagen.

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

> ⚠️ Las URLs de DALL-E expiran en ~60 minutos. Publicar en Instagram inmediatamente
> tras generarla. Guardar `revised_prompt` por si hay que regenerar.

---

### Paso 3 — Guardar resultado

Guarda los metadatos de la imagen generada en `.claude/posts/images/`:

```bash
mkdir -p .claude/posts/images
```

Crea el archivo `.claude/posts/images/{FECHA}.json`:
```json
{
  "date": "2026-03-21",
  "provider": "fal",
  "model": "flux/schnell",
  "prompt_used": "fotografía de producto industrial...",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "topic": "reducción de desperdicios en manufactura",
  "category": "Educativo / tip del sector",
  "platform": "instagram",
  "expires_at": null
}
```

> `expires_at`: null para fal.ai (URLs persistentes), timestamp ISO para DALL-E (+60min).

---

### Paso 4 — Si no hay API key disponible

Informar claramente:
```
⚠️  No se encontró FAL_KEY ni OPENAI_API_KEY en .env

Para generar imágenes automáticamente, agrega una de estas variables:

  Opción A — fal.ai (recomendado, ~$0.003/imagen):
    FAL_KEY=tu_key_aqui
    Obtener en: https://fal.ai → Dashboard → API Keys

  Opción B — DALL-E 3 (~$0.04/imagen):
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
  "image_url": "https://...",
  "prompt_used": "...",
  "dimensions": "1024x1024",
  "ready_for_instagram": true
}
```

---

## Precios de referencia

| Proveedor | Modelo | Precio/imagen | Velocidad | Recomendado para |
|---|---|---|---|---|
| fal.ai | FLUX Schnell (8 pasos) | ~$0.003 | ~3 seg | Solo producto/objeto, sin personas |
| fal.ai | FLUX Dev (28 pasos) | ~$0.025 | ~15 seg | Con personas — mejor calidad anatómica |
| OpenAI | DALL-E 3 Standard | ~$0.040 | ~10 seg | No recomendado — usar HD |
| OpenAI | DALL-E 3 HD | ~$0.080 | ~15 seg | Alternativa cuando no hay FAL_KEY |

---

## Notas

- Las URLs de fal.ai son persistentes (no expiran) — ideales para Instagram Graph API
- Si el post tiene una fecha especial (ej. Día de la Mujer), incluirlo en el prompt
- El prompt nunca debe pedir texto dentro de la imagen — Instagram lo procesa mejor sin texto
- Si la empresa tiene colores de marca en `brand_style.color_palette`, incluirlos siempre
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

**Regla de oro para marketing B2B:** si el tópico lo permite, preferir siempre
**fotografía de producto o entorno** sin personas. Evita el 100% de los problemas
anatómicos y la imagen queda más limpia para redes sociales.
