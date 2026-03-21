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

### Paso 2 — Construir el prompt de imagen

Combina el estilo de marca + tópico + requisitos de plataforma.

**Estructura del prompt:**
```
{estilo_fotografico}, {mood}, colores dominantes {palette}, {descripcion_visual_del_topico},
fotografía profesional B2B, {sector_industrial}, cuadrado 1:1, alta resolución,
estilo editorial corporativo, iluminación profesional, sin texto superpuesto
```

**Reglas de construcción:**

1. **Si existe `brand_style`** → úsalo como base:
   - `photography_style` → define el tipo de imagen (producto, lifestyle, abstracto, etc.)
   - `mood` → tono emocional (profesional, cálido, innovador, etc.)
   - `color_palette` → mencionar los colores hex o sus equivalentes descriptivos
   - `elements` → incluir elementos recurrentes de la marca si son visuales

2. **Si NO existe `brand_style`** → generar un prompt limpio y profesional basado en
   el sector de la empresa y el tópico del post.

3. **Adaptar el tópico al visual:**
   - "tips de reducción de desperdicios" → imagen de proceso industrial ordenado, eficiente
   - "caso de éxito" → imagen de personas de negocios satisfechas o producto destacado
   - "tendencia de mercado" → imagen abstracta con datos, gráficos, tecnología
   - "detrás de escena" → fotografía auténtica del proceso o equipo
   - "Día Internacional de la Mujer" → imagen que celebre el liderazgo femenino en el sector

4. **Para Instagram**: especificar `square_hd` (1024×1024)
   **Para Facebook**: especificar `landscape_4_3` (1280×960)

**Ejemplo de prompt resultante:**
```
fotografía de producto industrial sobre fondo blanco neutro, ambiente profesional y limpio,
colores cálidos (beige #F5E6D0, azul oscuro #1A2B3C, blanco #FFFFFF),
maquinaria de precisión con detalles técnicos, sector manufactura textil, cuadrado 1:1,
luz de estudio difusa, sin texto superpuesto, alta resolución, comercial, editorial
```

---

### Paso 2A — Generar con fal.ai FLUX

**Modelo recomendado:** `fal-ai/flux/schnell` (rápido, económico ~$0.003/imagen)
**Modelo premium:** `fal-ai/flux/dev` (mayor calidad ~$0.025/imagen, usar si el post es especial)

```bash
# Leer FAL_KEY del .env
FAL_KEY=$(grep "^FAL_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

# Para Instagram (cuadrado)
curl -s -X POST "https://fal.run/fal-ai/flux/schnell" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "{PROMPT_CONSTRUIDO}",
    "image_size": "square_hd",
    "num_inference_steps": 4,
    "num_images": 1,
    "enable_safety_checker": true
  }'
```

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

Extraer: `images[0].url` → esta es la URL pública para Instagram.

**Si `has_nsfw_concepts[0]` es `true`** → regenerar con el mismo prompt (máximo 2 intentos).

---

### Paso 2B — Generar con DALL-E 3 (alternativa)

```bash
# Leer OPENAI_API_KEY del .env
OPENAI_KEY=$(grep "^OPENAI_API_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "{PROMPT_CONSTRUIDO}",
    "size": "1024x1024",
    "quality": "standard",
    "style": "natural",
    "n": 1
  }'
```

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

> ⚠️ Las URLs de DALL-E expiran en ~60 minutos. Usar inmediatamente para publicar o guardar el
> `revised_prompt` para regenerar después.

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

| Proveedor | Modelo | Precio/imagen | Velocidad |
|---|---|---|---|
| fal.ai | FLUX Schnell | ~$0.003 | ~3 segundos |
| fal.ai | FLUX Dev | ~$0.025 | ~15 segundos |
| OpenAI | DALL-E 3 Standard | ~$0.040 | ~10 segundos |
| OpenAI | DALL-E 3 HD | ~$0.080 | ~15 segundos |

---

## Notas

- Las URLs de fal.ai son persistentes (no expiran) — ideales para Instagram Graph API
- Si el post tiene una fecha especial (ej. Día de la Mujer), incluirlo en el prompt
- El prompt nunca debe pedir texto dentro de la imagen — Instagram lo procesa mejor sin texto
- Si la empresa tiene colores de marca en `brand_style.color_palette`, incluirlos siempre
- Compatible con la Instagram Graph API: `image_url` se pasa directamente en el paso de
  creación del media container
