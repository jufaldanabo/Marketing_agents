# /publish-today — Agente Publicador B2B

Genera contenido B2B de alta calidad y lo publica en Instagram y Facebook.
Opera de forma **autónoma**: no pregunta el tema — lo determina solo a partir de la
memoria de publicaciones anteriores, la parrilla de tópicos, el contexto del país y la fecha.

---

## Instrucciones para Claude

Eres el **Agente Publicador** de marketing B2B. Ejecuta estos pasos en orden.

---

### Paso 1 — Cargar contexto de empresa

Lee `.claude/company-context.json`. Extrae:
- `company.name`, `company.industry`, `company.product`, `company.tone`, `company.location`
- `icp.industry_target`, `market.competitors`

Si el archivo no existe, ejecuta `/init` primero.

---

### Paso 2 — Leer historial de publicaciones

Lee `.claude/posts/history.json`. Si no existe, créalo vacío:
```json
{ "posts": [] }
```

Del historial extrae los **últimos 7 posts**: tópico, categoría y fecha.
Objetivo: **no repetir** tópico ni categoría en los últimos 7 días.

---

### Paso 3 — Leer (o crear) la parrilla de tópicos

Lee `.claude/content-calendar.json`. Si no existe, créalo con esta estructura base
adaptada al sector de la empresa:

```json
{
  "categories": [
    {
      "name": "Producto / servicio",
      "description": "Destacar características, usos y ventajas del producto",
      "weight": 2
    },
    {
      "name": "Educativo / tip del sector",
      "description": "Enseñar algo útil a los clientes sobre la industria",
      "weight": 2
    },
    {
      "name": "Caso de éxito / testimonio",
      "description": "Historia real de un cliente o resultado logrado",
      "weight": 1
    },
    {
      "name": "Detrás de escena / equipo",
      "description": "Mostrar el proceso, el equipo o la cultura de la empresa",
      "weight": 1
    },
    {
      "name": "Tendencia de mercado",
      "description": "Comentar una novedad relevante para los clientes B2B",
      "weight": 1
    },
    {
      "name": "Fecha especial / coyuntura",
      "description": "Aprovechar una fecha relevante del calendario o del sector",
      "weight": 1
    }
  ],
  "topics": []
}
```

> El campo `topics` es una lista libre que el usuario puede llenar con temas específicos.
> Si está vacío, el agente genera el tópico del día de forma autónoma.

---

### Paso 4 — Detectar contexto del día (fecha especial + eventos del país)

1. Obtén la fecha de hoy: `date +%Y-%m-%d`
2. Determina si hay una **fecha especial relevante** en el país de la empresa (`company.location`).
   Usa WebSearch: `"fecha especial [mes] [día] [país]"` o `"efeméride [fecha] [sector]"`

   Ejemplos de fechas que justifican contenido especial:
   - 8 de marzo → Día Internacional de la Mujer
   - 1 de mayo → Día del Trabajo
   - Fechas nacionales del país de la empresa
   - Fechas relevantes del sector (ferias, temporadas)

3. Si hay fecha especial → forzar categoría `"Fecha especial / coyuntura"` para el post de hoy.
4. Si no hay fecha especial → elegir la categoría menos usada en los últimos 7 días (mayor rotación).

---

### Paso 5 — Elegir el tópico del día

**Si el usuario pasó un argumento** (ej. `/publish-today "nueva línea de productos"`) → usar ese tópico directamente.

**Si `content-calendar.json` tiene `topics[]` con entradas no usadas recientemente** → tomar el siguiente de la lista.

**Si no hay tópicos predefinidos** → generar uno autónomamente según la categoría elegida, el producto de la empresa, la fecha y el contexto del mercado.

Registra la decisión: `{fecha, categoria, topico, fuente: "calendario"|"argumento"|"autónomo"}`.

---

### Paso 6A — Analizar brand kit de imágenes (si existe)

Verifica si existe la carpeta `.claude/brand-images/`:
```bash
ls .claude/brand-images/ 2>/dev/null
```

**Si la carpeta contiene imágenes** (jpg, png, webp):
1. Lee hasta 5 imágenes con la herramienta de visión.
2. Extrae el **estilo visual de la marca**: paleta de colores dominante, tipografía percibida, estilo fotográfico (plano, lifestyle, producto, etc.), elementos recurrentes.
3. Guarda este análisis en `.claude/brand-images/brand-style.json` para no repetirlo cada vez:
   ```json
   {
     "color_palette": ["#1A2B3C", "#F5E6D0", "#FFFFFF"],
     "photography_style": "fotografía de producto sobre fondo claro, sin personas",
     "mood": "profesional, limpio, moderno",
     "elements": ["logo en esquina inferior derecha", "tipografía sans-serif"],
     "analyzed_at": "2026-03-21"
   }
   ```
4. Si `brand-style.json` ya existe y fue analizado hace menos de 30 días, usar el análisis guardado.

**Si la carpeta no existe o está vacía** → continuar sin brand_style (la IA generará imagen basada en el sector).

---

### Paso 6B — Generar imagen con IA

Ejecuta el skill `skills/publishing/generate-image-ai.md` con estos inputs:

```
brand_style   → contenido de brand-style.json (o null)
topic         → {topico_elegido}
category      → {categoria_elegida}
company_name  → {company.name}
industry      → {company.industry}
special_date  → {fecha_especial o null}
platform      → "instagram"
```

El skill detecta automáticamente el proveedor disponible (`FAL_KEY` o `OPENAI_API_KEY`) y devuelve:

```json
{
  "success": true,
  "provider": "fal",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "prompt_used": "fotografía de producto industrial..."
}
```

**Si el skill devuelve `success: false` o no hay API key** → continuar con `image_url: null`
y mostrar el `prompt_externo` para uso manual en Artlist, Midjourney o Firefly.

---

### Paso 7 — Generar contenido

Usa el siguiente contexto para generar el post:

```
Empresa: {company.name}
Industria: {company.industry}
Producto: {company.product}
Tono: {company.tone}
Ubicación: {company.location}
Categoría del día: {categoria_elegida}
Tópico del día: {topico_elegido}
Fecha especial: {fecha_especial o "ninguna"}
Últimos tópicos publicados (no repetir): {lista de los últimos 7}
Estilo visual de la marca: {brand_style si existe}
```

Genera el siguiente JSON:

```json
{
  "instagram": {
    "caption": "Texto completo con emojis. Máx 2200 caracteres. Gancho en la primera línea.",
    "hashtags": ["hashtag1", "hashtag2"],
    "cta": "Llamada a la acción clara al final"
  },
  "facebook": {
    "mensaje": "Versión conversacional, 300-500 caracteres, sin hashtags excesivos"
  },
  "imagen": {
    "url_generada": "URL devuelta por el skill generate-image-ai (o null si falló)",
    "provider": "fal | openai | none",
    "prompt_usado": "Prompt exacto enviado a la IA",
    "prompt_externo": "Prompt para uso manual en Artlist / Midjourney / Firefly si no se generó automáticamente",
    "descripcion_alt": "Texto alternativo para accesibilidad"
  },
  "meta": {
    "categoria": "{categoria_elegida}",
    "topico": "{topico_elegido}",
    "fecha_especial": "{fecha_especial o null}",
    "resumen": "Una línea describiendo el contenido"
  }
}
```

---

### Paso 8 — Mostrar preview completo

```
📋 PREVIEW DEL CONTENIDO — {FECHA}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 Categoría: {categoria} | Tópico: {topico}
{si hay fecha especial: "🗓️ Contexto: {fecha_especial}"}

📸 INSTAGRAM
{caption}

{hashtags}

📘 FACEBOOK
{mensaje}

🖼️ IMAGEN
{si imagen.url_generada existe:
  "✅ Imagen generada con {imagen.provider}: {imagen.url_generada}"
  "📝 Prompt usado: {imagen.prompt_usado[0:120]}..."
sino:
  "⚠️  Sin API key — usa este prompt en Artlist/Midjourney/Firefly:"
  "{imagen.prompt_externo}"
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
¿Publicar en ambas plataformas? [Sí / No / Editar]
```

---

### Paso 9 — Publicar en Instagram

Si el usuario confirma, publica usando la **Instagram Graph API**.

Usa `imagen.url_generada` del Paso 6B como `image_url`. Si es null, Instagram requiere
una URL pública — informar al usuario y guardar el post como borrador.

**Con imagen (URL generada por IA o proporcionada manualmente):**
```
POST https://graph.facebook.com/v21.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/media
  image_url={imagen.url_generada}
  caption={CAPTION}\n\n{HASHTAGS}
  access_token={INSTAGRAM_ACCESS_TOKEN}

POST https://graph.facebook.com/v21.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/media_publish
  creation_id={CREATION_ID}
  access_token={INSTAGRAM_ACCESS_TOKEN}
```

**Sin imagen disponible (`url_generada` es null):**
- Informar: "Instagram requiere imagen. Genera una con el prompt en Artlist (toolkit.artlist.io) o Midjourney y proporciona la URL."
- Guardar el post como borrador con `"published": false`.
- Continuar con Facebook (acepta posts sin imagen).

---

### Paso 10 — Publicar en Facebook

```
POST https://graph.facebook.com/v21.0/{FACEBOOK_PAGE_ID}/feed
  message={MENSAJE_FACEBOOK}
  access_token={FACEBOOK_ACCESS_TOKEN}
```

Con imagen:
```
POST https://graph.facebook.com/v21.0/{FACEBOOK_PAGE_ID}/photos
  url={URL_IMAGEN}
  message={MENSAJE_FACEBOOK}
  access_token={FACEBOOK_ACCESS_TOKEN}
```

---

### Paso 11 — Guardar en historial y confirmar

**Guarda el post en `.claude/posts/{FECHA}.json`:**
```json
{
  "date": "2026-03-21",
  "category": "Fecha especial / coyuntura",
  "topic": "Día Internacional de la Mujer",
  "instagram_post_id": "...",
  "facebook_post_id": "...",
  "caption_preview": "Primeros 100 caracteres...",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "image_provider": "fal",
  "image_prompt": "Prompt exacto usado para generar la imagen...",
  "published": true
}
```

**Actualiza `.claude/posts/history.json`** — agrega este post al array `posts[]`, mantén solo los últimos 30.

**Muestra confirmación:**
```
✅ PUBLICACIÓN COMPLETADA

📸 Instagram: Post ID {ID} publicado
📘 Facebook: Post ID {ID} publicado

📌 Tópico: {topico}
📅 Fecha: {HOY}
🏢 Empresa: {COMPANY_NAME}

💾 Historial actualizado: .claude/posts/history.json
   Próxima categoría sugerida: {siguiente_categoria_en_rotación}
```

---

## Variables requeridas

| Variable | Fuente | Descripción |
|---|---|---|
| `COMPANY_NAME` | `.claude/company-context.json` | Nombre de la empresa |
| `INDUSTRY` | `.claude/company-context.json` | Sector industrial |
| `INSTAGRAM_ACCESS_TOKEN` | `.env` | Token de Instagram Graph API |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | `.env` | ID de cuenta Instagram |
| `FACEBOOK_ACCESS_TOKEN` | `.env` | Token de Facebook |
| `FACEBOOK_PAGE_ID` | `.env` | ID de página Facebook |
| `FAL_KEY` | `.env` | **Generación de imágenes** — fal.ai (recomendado) |
| `OPENAI_API_KEY` | `.env` | **Generación de imágenes** — DALL-E 3 (alternativa) |

## Archivos del sistema

| Archivo | Propósito |
|---|---|
| `.claude/company-context.json` | Contexto de empresa (generado por `/init`) |
| `.claude/posts/history.json` | Historial de los últimos 30 posts |
| `.claude/posts/images/{FECHA}.json` | Metadatos de la imagen generada por IA |
| `.claude/content-calendar.json` | Parrilla de categorías y tópicos |
| `.claude/brand-images/` | Carpeta con imágenes de marca (opcional) |
| `.claude/brand-images/brand-style.json` | Análisis visual del brand kit (auto-generado) |

## Comportamiento ante errores

- **Error de API**: Mostrar el error exacto, guardar el contenido en `.claude/posts/{FECHA}.json` con `"published": false`
- **Token expirado**: Ejecutar `/setup-check` para verificar y renovar
- **Sin imagen**: Facebook con texto puro; Instagram guarda para publicación manual
- **`company-context.json` no existe**: Solicitar ejecutar `/init` primero

## Notas

- El tópico del día **nunca se le pregunta al usuario** — se determina automáticamente
- Si el usuario llama `/publish-today "tema específico"`, ese argumento override la selección automática
- La carpeta `.claude/brand-images/` la crea el usuario manualmente copiando 5-10 fotos de su marca
- **Generación de imágenes**: automática si hay `FAL_KEY` o `OPENAI_API_KEY`; si no, se genera un
  `prompt_externo` listo para usar en Artlist (toolkit.artlist.io), Midjourney o Firefly
- Las URLs de fal.ai son persistentes y se pueden usar directamente en Instagram Graph API
- Usar `claude-opus-4-6` con `thinking: adaptive` para la generación de contenido
