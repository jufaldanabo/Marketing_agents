---
name: generate-reel
description: Generates a complete short-form reel package (scene-by-scene script, text overlays, trending audio suggestion, cover image and caption) ready to film. Delegates image generation to generate-image-ai (never calls fal.ai directly).
allowed-tools: [Read, Write, WebSearch]
model: claude-opus-4-7
---

# Skill: generate-reel

> **DELEGAR a `generate-image-ai`**: Este skill NO debe llamar a fal.ai directamente.
> La cover image y las imágenes de referencia de escena se generan invocando el skill
> `generate-image-ai`, que encapsula prompts conversacionales, modos text-to-image/edit-image,
> y guardado de artefactos. Este skill solo construye el `topic`, `category`, `platform`
> y la descripción visual, y recibe de vuelta la `image_url` pública.


**Propósito**: Genera un reel completo: guión escena por escena, text overlays,
sugerencia de audio, cover image, y caption. Listo para filmar o producir.
**Herramientas**: fal.ai (cover image), WebSearch (trending audio)
**Usado por**: `/publish-today` cuando `artifact_type == "reel"`

---

## Cuándo usar este skill

Cuando la parrilla indica `artifact_type: "reel"` o el agente decide que el formato
video corto es el más efectivo para el tema (tips rápidos, behind the scenes, trends).

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `topic` | string | Tema del reel |
| `content_pillar` | string | Pilar de contenido |
| `company_name` | string | Nombre de la empresa |
| `industry` | string | Sector |
| `brief` | string | Descripción del contenido |
| `brand_kit` | object | Brand kit completo |

### Inputs opcionales

| Input | Tipo | Default |
|---|---|---|
| `duration` | string | "30s" (15s / 30s / 60s / 90s) |
| `reel_style` | string | Se elige automáticamente según pilar |
| `platform` | string | "instagram" (también aplica para TikTok y FB Reels) |
| `hook` | string | Se genera si no viene |

---

## Anatomía de un reel efectivo

```
SEGUNDO 0-3 — HOOK (los más críticos)
  → Si no enganchas aquí, pierdes el 80% de la audiencia
  → Opciones: pregunta directa, dato impactante, acción visual sorprendente,
    text overlay provocador, "POV:", "No hagas esto si..."

SEGUNDO 3-10 — CONTEXTO
  → Establece de qué trata el reel
  → Muestra quién eres / dónde estás / qué vas a mostrar

SEGUNDO 10-25 — CONTENIDO PRINCIPAL
  → El valor real: tip, proceso, demostración, historia
  → Ritmo rápido, cambios de plano cada 2-3 segundos
  → Text overlays para reforzar puntos clave

SEGUNDO 25-30 — CIERRE + CTA
  → Resultado final, revelación, o resumen
  → CTA verbal o en texto: "Guarda esto", "Sígueme para más", "Comenta tu favorito"
```

---

## Proceso de generación

### Paso 1 — Buscar audio trending (opcional)

```
WebSearch: "trending audio reels {MES} {AÑO}"
WebSearch: "trending sounds Instagram reels {INDUSTRY}"
WebSearch: "viral audio reels español {AÑO}"
```

Si se encuentra un audio trending relevante, incluirlo como sugerencia.
Si no, sugerir tipo de audio (lo-fi, upbeat, trending pop, narración sin música).

### Paso 2 — Elegir estilo de reel

| Pilar | Estilos recomendados |
|---|---|
| Educativo | tutorial, tip rápido, "sabías que", antes/después, mythbusting |
| Informativo | dato del día, noticias del sector, explicación rápida |
| Entretenimiento | trending format, POV, día en la vida, expectativa vs realidad |
| Inspiracional | behind the scenes, proceso completo en timelapse, transformación |
| Promocional | reveal de producto, unboxing, "lo que incluye", before/after |
| Interactivo | "¿cuál prefieres?", challenge, "respondo comentarios" |

### Paso 3 — Generar guión completo

```
SYSTEM:
Eres un creador de contenido vertical (reels/TikTok) especializado en {INDUSTRY}.
Dominas el ritmo, el hook, y la retención. Tu contenido se ve auténtico, no corporativo.
{BRAND_KIT.prompt_injection.content_prefix}

USER:
Genera el guión completo de un reel sobre:

Tema: {TOPIC}
Pilar: {CONTENT_PILLAR}
Empresa: {COMPANY_NAME}
Sector: {INDUSTRY}
Brief: {BRIEF}
Duración objetivo: {DURATION}
Estilo: {REEL_STYLE}

PERSONALIDAD DE MARCA:
{BRAND_KIT.content_voice.personality}
Tono: {BRAND_KIT.content_voice.tone_spectrum}
Emojis: {BRAND_KIT.content_voice.emoji_usage}
Evitar: {BRAND_KIT.content_voice.forbidden_words}

REGLAS PARA REELS:
1. Hook en los primeros 3 segundos — debe detener el scroll
2. Cambio de plano o movimiento cada 2-3 segundos (mantener ritmo)
3. Text overlays grandes y legibles (estilo: {BRAND_KIT.typography.text_on_images})
4. Colores de marca en text overlays: {BRAND_KIT.colors.primary} sobre fondo, blanco sobre imagen oscura
5. Narración en primera persona o voz de marca, NUNCA tono noticiero
6. El reel debe funcionar también SIN audio (text overlays cuentan la historia)
7. Máximo 90 segundos. Si el contenido se puede dar en 30s, mejor
8. Cierre con CTA natural, no forzado

Devuelve JSON:
{
  "reel_title": "título interno del reel",
  "reel_style": "tutorial|pov|behind_scenes|tip|trending|reveal|storytelling",
  "duration_seconds": 30,
  "hook_type": "pregunta|dato|accion|pov|contradiccion",

  "scenes": [
    {
      "number": 1,
      "timestamp": "0:00-0:03",
      "duration_seconds": 3,
      "role": "hook",
      "action": "Descripción exacta de lo que se ve en cámara",
      "narration": "Lo que se dice en voz (o null si solo hay text overlay)",
      "text_overlay": {
        "text": "Texto que aparece en pantalla (máx 8 palabras)",
        "position": "center|top|bottom",
        "style": "bold|handwritten|minimal",
        "color": "#hex",
        "animation": "appear|typewriter|bounce|none"
      },
      "camera": {
        "shot": "close-up|medium|wide|overhead|pov",
        "movement": "static|pan|zoom-in|zoom-out|follow|handheld",
        "angle": "eye-level|high|low|45deg"
      },
      "visual_description": "Descripción detallada para generar la imagen de referencia de esta escena"
    }
  ],

  "audio": {
    "type": "trending_song|original_narration|voiceover|ambient|lo-fi|none",
    "suggestion": "nombre de canción o tipo de audio sugerido",
    "trending_audio": "nombre del audio trending si se detectó",
    "narration_full": "Texto completo de la narración del reel, si aplica"
  },

  "cover_image": {
    "description": "Descripción de la thumbnail/cover ideal",
    "text_overlay": "Texto que va en la portada (gancho visual)",
    "image_prompt": "Prompt para generar la cover con IA"
  },

  "caption": "Caption de Instagram para el reel (incluye hashtags)",
  "hashtags": ["#hash1", "#hash2"],
  "cta": "Call to action del reel",

  "production_notes": {
    "equipment": "smartphone|camera|tripod|ring-light",
    "difficulty": "fácil|media|avanzada",
    "filming_time": "5min|15min|30min",
    "editing_tips": "consejos de edición",
    "best_time_to_post": "hora sugerida"
  }
}
```

### Paso 4 — Generar cover image

La cover/thumbnail es crítica — es lo que se ve en el feed y en la grilla del perfil.

Construir prompt con brand kit:

```
{BRAND_KIT.prompt_injection.image_prefix}

Thumbnail para reel de {INDUSTRY} sobre "{TOPIC}".
{cover_image.description}

REQUISITOS DE COVER:
- Formato vertical 9:16 (1080x1920px) o cuadrado si es para grilla
- Imagen que genere curiosidad y ganas de ver el video
- Espacio para text overlay en zona: {text_position}
- Colores de marca: {BRAND_KIT.colors.primary}, {BRAND_KIT.colors.secondary}
- Estilo: {BRAND_KIT.visual_identity.photography_style}
- Mood: {BRAND_KIT.visual_identity.mood}

{BRAND_KIT.prompt_injection.image_suffix}
```

**Delegar a `generate-image-ai`** para la cover (no llamar a fal.ai directamente):

Invocar `generate-image-ai` con:
- `topic`: el `cover_image.text_overlay` o la descripción resumida de la portada
- `category`: `content_pillar` del reel
- `company_name`, `industry`: inputs del reel
- `platform`: "instagram" (cover 1:1 para grilla; para 9:16 ver nota abajo)
- `brand_style`: `brand_kit` del input
- Descripción visual: `cover_image.description` + estilo del `brand_kit`

Recibir `image_url` pública y asignarla a `cover_image.url`. Si se necesita 9:16
vertical para la cover del reel, el formato por defecto `square_hd` de `generate-image-ai`
se usa para la grilla; para el video en sí la cover suele importarse en el editor
de video a partir del frame o de esta misma imagen.

### Paso 5 — Generar imágenes de referencia por escena (opcional)

Si `FAL_KEY` está disponible, generar una imagen de referencia para las escenas clave
(hook, escena principal, cierre). Esto ayuda a visualizar el reel antes de filmarlo.

Solo para escenas con `role: "hook"` y `role: "climax"` — no todas las escenas.

**Delegar a `generate-image-ai`** (no llamar a fal.ai directamente): invocarlo una
vez por escena clave pasando la `visual_description` como contexto del prompt.

---

## Estructura de output completo

```json
{
  "artifact_type": "reel",
  "topic": "Cómo hacemos nuestra masa madre en Inside",
  "reel_style": "behind_scenes",
  "duration_seconds": 30,
  "scene_count": 6,

  "scenes": ["... array de escenas ..."],

  "audio": {
    "type": "trending_song",
    "suggestion": "Calm lo-fi beat o 'espresso' de Sabrina Carpenter (instrumental)",
    "narration_full": null
  },

  "cover_image": {
    "url": "https://fal.media/files/xxx/cover.jpeg",
    "prompt": "Close-up de masa madre burbujeante..."
  },

  "caption": "El secreto de nuestro pan tiene 24 horas de historia 🕐🍞\n\nAsí hacemos la masa madre en Inside...\n\n#MasaMadre #PanArtesanal #Inside",
  "hashtags": ["#MasaMadre", "#PanArtesanal", "#Inside"],

  "production_notes": {
    "equipment": "smartphone con trípode",
    "difficulty": "fácil",
    "filming_time": "15min",
    "editing_tips": "Usar CapCut o InShot para cortes rápidos. Velocidad 2x en escenas de proceso."
  },

  "scene_reference_images": [
    {"scene": 1, "url": "https://fal.media/...", "role": "hook"},
    {"scene": 5, "url": "https://fal.media/...", "role": "climax"}
  ]
}
```

---

## Publicación en Instagram (Graph API)

Los reels en Instagram se publican como video:

### Si se tiene el video editado:
```
POST https://graph.facebook.com/v21.0/{IG_ACCOUNT_ID}/media
  media_type=REELS
  video_url={VIDEO_URL}
  caption={CAPTION}
  cover_url={COVER_IMAGE_URL}
  share_to_feed=true
  access_token={TOKEN}
```

### Polling hasta que el video esté procesado:
```
GET https://graph.facebook.com/v21.0/{CREATION_ID}
  fields=status_code
  access_token={TOKEN}

Esperar hasta status_code == "FINISHED"
```

### Publicar:
```
POST https://graph.facebook.com/v21.0/{IG_ACCOUNT_ID}/media_publish
  creation_id={CREATION_ID}
  access_token={TOKEN}
```

---

## Estilos de reel por formato

### Tutorial / Tip rápido
```
Hook: "Truco que ojalá me hubieran dicho antes" + acción visual
Desarrollo: 3-5 pasos cortos con text overlay numerado
Cierre: Resultado + "¿Conocías este truco?"
Audio: Lo-fi beat o trending instrumental
```

### POV / Day in the life
```
Hook: "POV: eres panadero a las 4am" + despertador sonando
Desarrollo: Secuencia cronológica del día, ritmo rápido
Cierre: Primer cliente + producto final
Audio: Trending song que coincida con el mood
```

### Before/After / Reveal
```
Hook: "De esto... a ESTO" + imagen antes
Desarrollo: Proceso rápido (timelapse)
Cierre: Reveal dramático del producto final
Audio: Sound con buildup y drop
```

### Trending format adaptation
```
Hook: Adaptar el trend al sector (ej: "Tell me you're a baker without telling me")
Desarrollo: Seguir la estructura del trend con contenido de marca
Cierre: Giro inesperado o humor del sector
Audio: El audio trending original
```

---

## Cross-platform

| Campo | Instagram Reel | TikTok | Facebook Reel |
|---|---|---|---|
| Duración | 15-90s | 15-180s | 15-90s |
| Ratio | 9:16 | 9:16 | 9:16 |
| Caption | Hasta 2200 chars | Hasta 2200 chars | Hasta 2200 chars |
| Hashtags | 5-10 | 3-5 | 3-5 |
| Audio | IG music library | TikTok sounds | FB music library |
| Cover | Sí (recomendada) | Sí | Sí |
| Watermark | Evitar logo TikTok | Evitar logo IG | Evitar logos |

**Regla**: NUNCA repostear el mismo video con watermark de otra plataforma.
Exportar siempre sin watermark y subir como nativo.

---

## Notas de implementación

- El reel NO se produce automáticamente — se genera el guión y material de referencia
- La cover image SÍ se genera con IA (es una imagen estática)
- Las imágenes de referencia por escena son OPCIONALES (solo para visualización)
- El guión debe ser lo suficientemente detallado para que alguien lo filme solo
- Si no hay FAL_KEY, generar solo los prompts de imagen para uso externo
- El caption se optimiza por separado para cada plataforma si hay cross-post
- Incluir siempre production_notes para que el equipo sepa qué necesita
