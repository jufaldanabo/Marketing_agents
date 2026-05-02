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

### Paso 6 — Preguntar al manager por Telegram: generar imagen o subir foto

Antes de generar la imagen, enviar un mensaje a Telegram informando el tópico del día
y preguntando cómo quiere manejar la imagen.

#### 6a — Enviar mensaje de opción de imagen a Telegram

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "parse_mode": "Markdown",
  "text": "🖼 *Imagen para el post de hoy*\n📅 {FECHA} | 🏢 {COMPANY_NAME}\n\n📌 *Categoría:* {CATEGORIA}\n📝 *Tópico:* {TOPICO}\n{si fecha especial: 🗓 *Contexto:* {FECHA_ESPECIAL}}\n\n¿Cómo quieres la imagen?\n\n📸 Envía una *foto* a este chat → la uso como base y la edito con IA\n🤖 Escribe *generar* → creo una imagen desde cero con IA"
}
```

Mostrar en consola:
```
📨 Pregunta enviada a Telegram: ¿foto propia o generar con IA?
   Esperando respuesta del manager...
   Timeout: 10 minutos.
```

#### 6b — Esperar respuesta del manager (polling)

Leer offset desde `.claude/drafts/_telegram_offset.json` (si no existe, crearlo con `{"offset": 0}`).

Repetir cada **15 segundos** hasta recibir respuesta o agotar 10 minutos:

```
GET https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getUpdates
  ?offset={OFFSET}
  &limit=10
  &timeout=10
```

Para cada mensaje recibido de `TELEGRAM_CHAT_ID`, clasificar (case insensitive):

**GENERAR** — el manager quiere imagen generada por IA:
`generar`, `genera`, `créala`, `hazla`, `ia`, `automática`, `crear`,
`genérala`, `dale`, `sí`

**FOTO** — el manager envió una imagen:
El mensaje contiene `message.photo` (array de tamaños de foto de Telegram).

**Si el mensaje es ambiguo** (texto sin foto que no encaja en "generar"):
Responder en Telegram: `🤔 Envía una foto o escribe *generar* para crear una con IA.`
Seguir esperando.

Actualizar offset a `update_id + 1` y guardar en `_telegram_offset.json`.

#### 6c — Si el manager eligió GENERAR (text-to-image)

Ejecutar `skills/publishing/generate-image-ai.md` con:

```
mode          → "text-to-image"
topic         → {topico_elegido}
category      → {categoria_elegida}
company_name  → {company.name}
industry      → {company.industry}
special_date  → {fecha_especial o null}
platform      → "instagram"
```

El skill genera una imagen nueva desde cero y devuelve:
```json
{
  "success": true,
  "mode": "text-to-image",
  "image_url": "https://fal.media/files/xxx/generated.jpeg",
  "prompt_used": "..."
}
```

**Si falla o no hay API key** → continuar con `image_url: null` y mostrar el prompt externo.

→ Continuar al **Paso 7**.

#### 6d — Si el manager envió una FOTO (edit-image)

1. Obtener el `file_id` de la foto en mayor resolución (último elemento del array `message.photo`).

2. Obtener la URL del archivo:
```
GET https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getFile
  ?file_id={FILE_ID}
```
Respuesta: `{"result": {"file_path": "photos/file_123.jpg"}}`

3. Descargar la foto:
```
GET https://api.telegram.org/file/bot{TELEGRAM_BOT_TOKEN}/{FILE_PATH}
```
Guardar en `.claude/brand-images/telegram-upload/{FECHA}.jpg`

4. Confirmar por Telegram:
```
✅ Foto recibida. Editando con IA para adaptarla al tópico del día...
```

5. Ejecutar `skills/publishing/generate-image-ai.md` con:

```
mode          → "edit-image"
topic         → {topico_elegido}
category      → {categoria_elegida}
company_name  → {company.name}
industry      → {company.industry}
special_date  → {fecha_especial o null}
platform      → "instagram"
image_path    → ".claude/brand-images/telegram-upload/{FECHA}.jpg"
```

El skill edita la foto con IA (fal-ai/flux-pro/edit) preservando el producto y
cambiando el contexto/ambientación según el tópico, y devuelve:
```json
{
  "success": true,
  "mode": "edit-image",
  "image_url": "https://fal.media/files/xxx/edited.jpeg",
  "prompt_used": "..."
}
```

→ Continuar al **Paso 7**.

#### 6e — Timeout (10 min sin respuesta)

```
⏰ Timeout: no se recibió respuesta sobre la imagen.
   Generando imagen automáticamente con IA (text-to-image)...
```

Ejecutar como en el paso 6c (text-to-image por defecto).

→ Continuar al **Paso 7**.

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
Imagen: {mode del Paso 6: "text-to-image" o "edit-image"}
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

### Paso 8 — Enviar preview a Telegram para aprobación

En lugar de pedir confirmación en la consola, envía el contenido completo al manager
por Telegram y espera su respuesta directamente en ese chat.

#### 8a — Generar draft_id

```
draft_id = primeros 8 caracteres del SHA1 de (TIMESTAMP + TOPICO)
```

#### 8b — Guardar borrador en disco

Guardar en `.claude/drafts/{draft_id}.json` con `status: "pending_approval"` y todo
el contenido generado (instagram, facebook, imagen). Mismo formato que
`skills/publishing/content-approval.md`.

#### 8c — Enviar mensaje de preview a Telegram

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "parse_mode": "Markdown",
  "text": "📝 *BORRADOR #{DRAFT_ID} listo para publicar*\n📅 {FECHA} | 🏢 {COMPANY_NAME}\nTema: _{TOPICO}_\n\n━━━ 📸 INSTAGRAM ━━━\n{CAPTION_COMPLETO}\n\n_{HASHTAGS}_\n\n━━━ 👥 FACEBOOK ━━━\n{MENSAJE_FACEBOOK}\n\n🖼 _Imagen: {imagen.descripcion_alt}_\n{si imagen.url_generada: imagen.url_generada}\n\n━━━━━━━━━━━━━━━━━━━━\nResponde en este chat:\n✅ *Sí* / *ok* / *dale* / *aprobado* → publica\n✍️ *editar: [cambios]* → corrige y reenvía\n❌ *no* / *rechazar* → cancela"
}
```

Guardar el `message_id` de la respuesta en el draft JSON (`telegram_message_id`).

Mostrar en consola:
```
📨 Preview enviado a Telegram. Esperando respuesta del manager...
   (Draft ID: {DRAFT_ID})
   Timeout: 10 minutos. Si no hay respuesta, el borrador queda guardado
   y puedes publicarlo después con /check-approvals.
```

---

### Paso 8.1 — Esperar respuesta del manager en Telegram

Hacer polling al endpoint `getUpdates` de Telegram hasta recibir una respuesta
del manager o alcanzar el timeout.

#### Leer offset actual

Leer `.claude/drafts/_telegram_offset.json`. Si no existe, crearlo con `{"offset": 0}`.

#### Loop de polling (máx 10 minutos)

Repetir cada **15 segundos** hasta recibir respuesta o agotar 10 minutos (40 intentos):

```
GET https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getUpdates
  ?offset={OFFSET}
  &limit=10
  &timeout=10
```

Para cada mensaje recibido en `result[]`:

1. Verificar que `message.chat.id == TELEGRAM_CHAT_ID`
2. Clasificar la intención del mensaje en lenguaje natural (case insensitive).
   No se requiere el `draft_id` — el agente ya sabe qué borrador está esperando.

   **APROBADO** — cualquiera de estas expresiones (o similares):
   `sí`, `si`, `ok`, `dale`, `va`, `listo`, `aprobado`, `aprobar`, `apruebo`,
   `publícalo`, `publicar`, `adelante`, `perfecto`, `está bien`, `sale`

   **EDITAR** — el mensaje contiene instrucciones de cambio:
   `editar: {instrucciones}`, `cambiar: {instrucciones}`, `cambia {instrucciones}`,
   o cualquier mensaje que pida modificaciones al contenido
   (ej. "ponle otro tono", "quita el precio", "hazlo más corto")

   **RECHAZADO** — negación clara:
   `no`, `rechazar`, `rechazado`, `cancelar`, `no publicar`, `descarta`,
   `no me gusta`, `mejor no`

   Si el mensaje es ambiguo (no encaja claramente en ninguna categoría),
   responder en Telegram: `🤔 No entendí. Responde *sí* para publicar, *no* para cancelar, o escribe los cambios que quieres.`
   y seguir esperando.

3. Actualizar offset a `update_id + 1` y guardar en `_telegram_offset.json`

#### Si la respuesta es APROBADO:

Mostrar en consola: `✅ Manager aprobó el borrador #{DRAFT_ID}. Publicando...`
Actualizar el draft: `status = "approved"`, `approved_at = NOW`.
→ Continuar al **Paso 9** (publicar).

#### Si la respuesta es EDITAR:

1. Regenerar el contenido con Claude aplicando las instrucciones del manager
2. Guardar nuevo borrador con nuevo `draft_id`
3. Enviar el nuevo preview a Telegram (repetir desde Paso 8c con el contenido editado)
4. Esperar nueva respuesta (repetir Paso 8.1)

#### Si la respuesta es RECHAZADO:

Actualizar el draft: `status = "rejected"`, `rejection_reason = {motivo}`.
Enviar confirmación a Telegram: `❌ Borrador #{DRAFT_ID} rechazado. No se publicará.`
Mostrar en consola:
```
❌ Manager rechazó el borrador #{DRAFT_ID}
   Motivo: {motivo}
   No se publicará. Ejecuta /publish-today para generar nuevo contenido.
```
→ **Terminar** (no continuar a Paso 9).

#### Si se agota el timeout (10 min sin respuesta):

Mostrar en consola:
```
⏰ Timeout: no se recibió respuesta en 10 minutos.
   El borrador #{DRAFT_ID} queda guardado en .claude/drafts/{draft_id}.json
   Opciones:
   • Responde en Telegram y luego ejecuta /check-approvals
   • /check-approvals --force {DRAFT_ID} para publicar sin aprobación
```
→ **Terminar** (el borrador queda pendiente para `/check-approvals`).

---

### Paso 9 — Publicar en Instagram

Solo se ejecuta si el manager aprobó en el Paso 8.1.

Publica usando la **Instagram Graph API**.

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

**Actualizar el borrador:** `status = "published"`, `published_at = NOW`.

**Guarda el post en `.claude/posts/{FECHA}.json`:**
```json
{
  "date": "2026-03-21",
  "category": "Fecha especial / coyuntura",
  "topic": "Día Internacional de la Mujer",
  "draft_id": "a3f9c21b",
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

**Envía confirmación por Telegram:**
```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "✅ Borrador #{DRAFT_ID} publicado con éxito\n📸 Instagram: Post ID {ID}\n👥 Facebook: Post ID {ID}\n📅 {FECHA}",
  "parse_mode": "Markdown"
}
```

**Muestra confirmación en consola:**
```
✅ PUBLICACIÓN COMPLETADA

📸 Instagram: Post ID {ID} publicado
📘 Facebook: Post ID {ID} publicado

📌 Tópico: {topico}
📅 Fecha: {HOY}
🏢 Empresa: {COMPANY_NAME}
📨 Confirmación enviada a Telegram

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
| `TELEGRAM_BOT_TOKEN` | `.env` | Token del bot de Telegram (aprobación de contenido) |
| `TELEGRAM_CHAT_ID` | `.env` | Chat ID donde enviar previews y recibir aprobación |
| `FAL_KEY` | `.env` | **Generación de imágenes** — fal.ai (recomendado) |
| `OPENAI_API_KEY` | `.env` | **Generación de imágenes** — DALL-E 3 (alternativa) |

## Archivos del sistema

| Archivo | Propósito |
|---|---|
| `.claude/company-context.json` | Contexto de empresa (generado por `/init`) |
| `.claude/posts/history.json` | Historial de los últimos 30 posts |
| `.claude/posts/images/{FECHA}.json` | Metadatos de la imagen generada por IA |
| `.claude/content-calendar.json` | Parrilla de categorías y tópicos |
| `.claude/brand-images/telegram-upload/` | Fotos enviadas por el manager via Telegram |
| `.claude/drafts/{draft_id}.json` | Borrador pendiente de aprobación por Telegram |
| `.claude/drafts/_telegram_offset.json` | Último update_id procesado del bot de Telegram |

## Comportamiento ante errores

- **Error de API**: Mostrar el error exacto, guardar el contenido en `.claude/posts/{FECHA}.json` con `"published": false`
- **Token expirado**: Ejecutar `/setup-check` para verificar y renovar
- **Sin imagen**: Facebook con texto puro; Instagram guarda para publicación manual
- **`company-context.json` no existe**: Solicitar ejecutar `/init` primero

## Notas

- El tópico del día **nunca se le pregunta al usuario** — se determina automáticamente
- Si el usuario llama `/publish-today "tema específico"`, ese argumento override la selección automática
- **Imagen**: el manager elige via Telegram si generar con IA (text-to-image) o subir foto propia (edit-image)
- Si sube foto, se edita con `fal-ai/flux-pro/edit` adaptando el contexto al tópico del día
- Si no responde en 10 min, se genera automáticamente con text-to-image
- Las URLs de fal.ai son persistentes y se pueden usar directamente en Instagram Graph API
- Usar `claude-opus-4-6` con `thinking: adaptive` para la generación de contenido
