# Command: /init

**Propósito**: Asistente de configuración inicial del toolkit. Recopila el contexto de la empresa
mediante una conversación guiada y genera los archivos de configuración necesarios para que
todos los skills funcionen correctamente.
**Modelo**: `claude-opus-4-6` (conversación interactiva)
**Skills usados**: `setup-check.md` (opcional al finalizar)

---

## Cuándo ejecutar

| Momento | Por qué |
|---|---|
| Primera vez que instala el toolkit | Crear la configuración base |
| Nuevo cliente o empresa | Resetear contexto para otra empresa |
| Cambio importante en el negocio | Actualizar ICP, productos o competidores |

---

## Flujo de ejecución

### Introducción

Presentarse antes de comenzar las preguntas:

```
¡Hola! Soy tu asistente de configuración del Marketing Toolkit.

Voy a hacerte algunas preguntas sobre tu empresa para que todos los
agentes de marketing, ventas e inteligencia de mercado funcionen
correctamente con tu negocio.

Tomaré entre 5 y 10 minutos. Puedes responder de manera informal —
no necesitas ser preciso/a, lo importante es capturar la esencia.

¿Empezamos?
```

---

### Fase 1 — La empresa

Hacer las siguientes preguntas **una a la vez**, esperando respuesta antes de continuar.
Adaptar el tono a cómo responda el usuario (formal/informal).

**Pregunta 1.1 — Nombre y sector:**
```
¿Cómo se llama tu empresa y a qué sector pertenece?
(Ejemplo: "Textiles El Valle, sector textil y confección")
```

**Pregunta 1.2 — Producto o servicio:**
```
¿Qué vende o produce tu empresa? Descríbelo brevemente.
(Ejemplo: "Telas para confección: algodón, licra y telas recicladas en rollos de 50m")
```

**Pregunta 1.3 — Tono de comunicación:**
```
¿Cómo describirías el tono de comunicación de tu marca?
(Ejemplo: "Cercano y directo, como hablar con un conocido del sector")

Opciones si no sabe:
- Formal y profesional
- Cercano e informal
- Técnico y especializado
- Aspiracional y moderno
```

**Pregunta 1.4 — Plataformas sociales:**
```
¿En qué redes sociales publicas o quieres publicar?
(Marca todas las que apliquen: Instagram / Facebook / TikTok)
```

**Pregunta 1.5 — Ciudad o país:**
```
¿Desde dónde opera tu empresa? (ciudad y país)
(Esto ayuda a contextualizar el contenido y la prospección)
```

---

### Fase 2 — Los clientes ideales

**Pregunta 2.1 — Sector objetivo:**
```
¿A qué tipo de empresas o personas les vendes?
(Ejemplo: "Talleres de confección medianos, diseñadoras independientes y marcas de ropa")
```

**Pregunta 2.2 — Geografía de prospectos:**
```
¿En qué ciudades o países están tus clientes potenciales?
(Ejemplo: "Bogotá, Medellín, Cali — principalmente Colombia")
```

**Pregunta 2.3 — Tamaño de empresa objetivo:**
```
¿Qué tamaño tienen tus clientes típicos?
(Ejemplo: "Empresas pequeñas de 5 a 50 empleados")

Opciones si no sabe:
- Emprendedores individuales
- Pequeñas empresas (1-20 empleados)
- Medianas empresas (20-200 empleados)
- Grandes empresas (+200 empleados)
- Mezcla de varios tamaños
```

**Pregunta 2.4 — Quién decide la compra:**
```
¿Quién suele tomar la decisión de compra en tus clientes?
(Ejemplo: "El dueño del taller o la jefa de producción")
```

**Pregunta 2.5 — Por qué te eligen:**
```
¿Por qué tus clientes te escogen a ti y no a la competencia?
(Ejemplo: "Por la calidad de la tela, el crédito a 30 días y la entrega rápida")
```

---

### Fase 3 — Competidores y mercado

**Pregunta 3.1 — Competidores principales:**
```
¿Quiénes son tus 2 o 3 principales competidores?
(Nombre de la empresa o marca. Si no tienes identificados, escribe "no sé")
```

**Pregunta 3.2 — Materias primas o insumos clave:**
```
¿Qué materias primas o commodities son más importantes para tu negocio?
(Ejemplo: "algodón, hilo de poliéster, lycra")

Esto permite monitorear precios automáticamente.
Si no aplica para tu negocio, escribe "ninguno".
```

**Pregunta 3.3 — Temas para análisis de tendencias (opcional):**
```
¿Hay temas sobre los que te gustaría monitorear tendencias semanales
en YouTube y TikTok? El comando /trend-ranking los usará como base.

(Ejemplo: "confección industrial, telas técnicas, moda sostenible")

Si no sabes aún, escribe "no sé" — puedes configurarlo después en .env como TREND_TOPICS.
```

Si responde con temas → guardar como `trend_topics` (lista) en `company-context.json` bajo `"market"`.
Si responde "no sé" o "ninguno" → registrar como `trend_topics: []`.

**Pregunta 3.4 — Canales YouTube o TikTok de competidores (opcional):**
```
¿Conoces los canales de YouTube o cuentas de TikTok de tus competidores?
Esto permite que /trend-ranking monitoree también su contenido.

(Ejemplo: "@CanalCompetidor en YouTube, @usuario_rival en TikTok")

Si no los conoces, escribe "no sé" — puedes agregarlo después.
```

Registrar por separado:
- `trend_competitors_yt`: lista de handles de YouTube (con @)
- `trend_competitors_tt`: lista de handles de TikTok (con @)

Si responde "no sé" → registrar ambos como `[]`.

---

### Fase 4 — El equipo comercial

**Pregunta 4.1 — Nombre del vendedor:**
```
¿Cómo se llama la persona que hace el contacto comercial o prospección?
(El nombre que aparecerá en los mensajes de LinkedIn, WhatsApp o email)
```

**Pregunta 4.2 — Cargo del vendedor:**
```
¿Cuál es su cargo o rol en la empresa?
(Ejemplo: "Gerente Comercial", "Asesor de Ventas", "Fundador")
```

---

### Fase 5 — Catálogo de productos e imágenes de referencia

Esta fase configura el motor visual del toolkit. Las fotos de referencia permiten al
generador de imágenes IA crear nuevas imágenes donde el producto aparece ambientado en
contextos reales (mesas, oficinas, personas de fondo, entornos industriales), preservando
su aspecto visual real sin publicar las fotos directamente.

**Pregunta 5.1 — ¿Cuántos productos o servicios?**
```
¿Tu empresa tiene un solo producto/servicio principal o varios?

Ejemplos:
  • "Uno solo: telas para confección"
  • "Varios: tela de algodón, tela de licra, hilos industriales"
```

**Si responde uno solo:**
- Usar el nombre de Fase 1.2 como producto principal → slug: `principal`
- Continuar directamente con Pregunta 5.2 para ese único producto

**Si responde varios:**
- Pedir que los nombre uno por uno (máximo 8 productos)
- Convertir cada nombre a slug: minúsculas, sin espacios, sin tildes
  (Ejemplo: "Tela de Algodón" → `tela-algodon`)
- Repetir Preguntas 5.2 y 5.3 para cada uno

---

**Pregunta 5.2 — Descripción del producto** (repetir por cada producto)

```
Para [{NOMBRE_PRODUCTO}], cuéntame:
  • ¿Qué es exactamente? (tipo de producto)
  • ¿De qué material es?
  • ¿Qué colores o acabados tiene?

No necesitas ser técnico — responde como si me lo describieras por teléfono.
Ejemplo: "Es un termo de acero negro, tiene tapa con boquilla para tomar directo"
```

---

**Pregunta 5.3 — Fotos de referencia** (repetir por cada producto)

```
¿Tienes fotos de [{NOMBRE_PRODUCTO}]?

Puedes:
  → Arrastrar las imágenes aquí directamente
  → Escribir la ruta del archivo (ej: /Users/juan/fotos/producto.jpg)
  → Escribir "no tengo" si aún no tienes fotos

Las fotos ayudan a generar imágenes de IA que se parezcan a tu producto real.
No se publican directamente.
```

**Para cada imagen proporcionada:**

1. Crear la carpeta del producto:
   ```bash
   mkdir -p .claude/brand-images/products/{PRODUCT_SLUG}
   ```

2. Copiar la imagen:
   ```bash
   cp "{RUTA_IMAGEN_USUARIO}" ".claude/brand-images/products/{PRODUCT_SLUG}/ref-{N}.{ext}"
   ```

3. Analizar visualmente con la herramienta de visión → extraer información detallada
   del producto para el paso siguiente.

**Si el usuario escribe "no tengo" o no tiene fotos:**
- Guardar `has_reference_images: false`
- Continuar con Pregunta 5.4 usando solo la descripción textual de 5.2

---

**Pregunta 5.4 — Generar y confirmar descripción técnica** (repetir por cada producto)

Con la información de la Pregunta 5.2 (descripción del usuario) y 5.3 (análisis visual
de la foto si la hay), generar una **descripción técnica completa y realista** del producto.

**Instrucciones para Claude:**

Usando `claude-opus-4-6`, generar una ficha técnica del producto que incluya:

1. **Nombre formal del producto** (categoría + tipo + diferenciador)
2. **Descripción técnica** en un párrafo (qué es, para qué sirve, cómo se ve)
3. **Características observadas** como lista estructurada:
   - Material y composición
   - Acabado exterior (color, textura, tipo de pintura/recubrimiento)
   - Capacidad o dimensiones estimadas
   - Partes y componentes visibles (tapas, asas, mecanismos, cierres)
   - Elementos funcionales (aislamiento, resistencia, flexibilidad)
   - Marca si es visible
   - Uso recomendado y contexto de uso
   - Dimensiones estimadas

**Si hay foto:** La descripción debe basarse principalmente en lo que se observa
en la imagen, complementado con la descripción verbal del usuario.

**Si no hay foto:** La descripción se basa en lo que dijo el usuario en 5.2,
enriquecida con conocimiento técnico del tipo de producto.

**Mostrar al usuario para confirmación:**

```
📋 FICHA TÉCNICA DE [{NOMBRE_PRODUCTO}]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏷️ Nombre: {NOMBRE_FORMAL}

📝 Descripción:
{DESCRIPCIÓN_TÉCNICA_PÁRRAFO}

📐 Características:
  • Material: {MATERIAL}
  • Acabado: {ACABADO}
  • Dimensiones: {DIMENSIONES}
  • Componentes: {PARTES_VISIBLES}
  • Uso: {USO_RECOMENDADO}
  {... más características según aplique}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Esta descripción se usará como contexto para generar imágenes
de tu producto con IA. ¿Es correcta?

  ✅ Sí, está bien
  ✍️ Corregir (dime qué cambiar)
```

**Si el usuario confirma:** Guardar como `technical_description` en `product-info.json`.

**Si el usuario pide correcciones:** Aplicar los cambios, regenerar la ficha y volver
a mostrar para confirmación. Repetir hasta que apruebe.

**Ejemplo real de descripción técnica generada:**

```
🏷️ Nombre: Botella Térmica Deportiva tipo Stanley

📝 Descripción:
Botella térmica deportiva de acero inoxidable con acabado negro mate
(powder coated). Diseño cilíndrico estilizado con perfil delgado y
ergonómico, orientado a portabilidad y uso activo. Cuenta con sistema
de tapa de doble función: boquilla tipo sport (flip-top) para beber
directamente sin desenroscar, integrada sobre una tapa rosca principal.

📐 Características:
  • Material: Acero inoxidable 18/8 (doble pared con aislamiento al vacío)
  • Acabado: Pintura powder coat negro mate, resistente a rayones
  • Capacidad: Entre 700 ml y 1 litro
  • Tapa: Sport con boquilla abatible (flip-top) y cierre hermético
  • Asa: Correa rígida tipo loop con pivote metálico
  • Boca: Angosta tipo sport, diseñada para beber directo
  • Aislamiento: Doble pared al vacío (frías 12-24h, calientes 6-12h)
  • Marca: Stanley (logo grabado verticalmente)
  • Uso: Hidratación deportiva, outdoor, oficina, uso diario
  • Libre de BPA: Sí
  • Dimensiones: ~28-30 cm alto × 7-8 cm diámetro
```

---

**Archivos generados por esta fase:**

Para cada producto, crear la carpeta `.claude/brand-images/products/{product_slug}/`
con el archivo `product-info.json`:

```json
{
  "name": "Tela de Algodón Premium",
  "slug": "tela-algodon",
  "description": "Rollos de tela de algodón 100% natural para confección",
  "technical_description": "Rollo de tela de algodón 100% natural para confección industrial. Tejido plano con acabado suave al tacto y caída fluida. Color beige claro uniforme con textura semi-mate. Presentación en rollos de ~50cm de ancho con etiqueta blanca identificativa en el centro. Material liviano y transpirable, apto para corte y costura en máquinas industriales.",
  "characteristics": {
    "material": "Algodón 100% natural, tejido plano",
    "acabado": "Beige claro, textura suave, semi-mate",
    "dimensiones": "Rollos de ~50cm de ancho, largo variable",
    "presentacion": "Enrollado en tubo de cartón con etiqueta central",
    "uso": "Confección industrial, corte y costura, diseño de moda"
  },
  "colors": ["beige", "crema", "#F5F0E8"],
  "keywords": ["algodón", "tela", "rollo", "natural", "confección", "textil"],
  "has_reference_images": true,
  "reference_images": ["ref-1.jpg", "ref-2.jpg"],
  "is_default": true,
  "description_approved_by_user": true
}
```

Además, crear el catálogo raíz `.claude/brand-images/products/product-catalog.json`:

```json
{
  "updated_at": "{TIMESTAMP_ISO}",
  "default_product": "{SLUG_DEL_PRIMER_PRODUCTO_O_PRINCIPAL}",
  "products": [
    {
      "slug": "tela-algodon",
      "name": "Tela de Algodón Premium",
      "keywords": ["algodón", "tela", "rollo", "natural"],
      "has_reference_images": true,
      "is_default": true
    },
    {
      "slug": "tela-licra",
      "name": "Licra Deportiva",
      "keywords": ["licra", "elastano", "deportivo", "stretch"],
      "has_reference_images": false,
      "is_default": false
    }
  ]
}
```

> El `default_product` es el que se usa cuando el tópico del post no coincide
> claramente con ningún producto específico del catálogo.

---

### Fase 6 — Credenciales

Preguntar sobre credenciales de manera no técnica:

```
Casi terminamos. Ahora necesito saber con qué canales digitales cuentas.

Para cada canal que mencionaste, ¿ya tienes las credenciales (tokens/claves) configuradas?
O ¿todavía necesitas obtenerlas?
```

Para cada plataforma activa (según Fase 1.4):

**Instagram / Facebook:**
```
¿Ya tienes el token de acceso de Meta (Instagram y Facebook)?
Si no lo tienes, puedo explicarte cómo obtenerlo después.
```

**TikTok:**
```
¿Ya tienes las credenciales de TikTok (access token y open_id)?
Necesitas una cuenta de desarrollador en developers.tiktok.com.
```

**Telegram (para notificaciones):**
```
¿Ya creaste el bot de Telegram y tienes el BOT_TOKEN y CHAT_ID?
Si no, te explico cómo en 2 minutos con @BotFather.
```

Registrar para cada uno: `tiene` / `necesita_obtener` / `no_aplica`

---

### Fase 7 — Confirmación y generación

Antes de generar los archivos, mostrar un resumen para confirmar:

```
Perfecto. Déjame resumir lo que registré:

🏢 EMPRESA
- Nombre: {COMPANY_NAME}
- Sector: {INDUSTRY}
- Producto: {PRODUCT}
- Tono: {TONE}
- Ciudad: {LOCATION}
- Plataformas: {PLATFORMS}

🎯 CLIENTE IDEAL
- Sector objetivo: {INDUSTRY_TARGET}
- Geografía: {GEOGRAPHY}
- Tamaño: {COMPANY_SIZE}
- Decisor: {DECISION_MAKER_ROLE}
- Por qué te eligen: {VALUE_PROPOSITION}

🖼️ PRODUCTOS / CATÁLOGO VISUAL
{PARA_CADA_PRODUCTO:}
- {PRODUCT_NAME}: {has_reference_images ? N fotos de referencia : sin fotos aún}
Catálogo: .claude/brand-images/products/product-catalog.json

📊 MERCADO
- Competidores: {COMPETITORS}
- Commodities a monitorear: {COMMODITIES}
- Temas para /trend-ranking: {TREND_TOPICS o "no configurado"}
- Competidores YouTube: {TREND_COMPETITORS_YT o "ninguno"}
- Competidores TikTok: {TREND_COMPETITORS_TT o "ninguno"}

👤 EQUIPO COMERCIAL
- Vendedor: {SENDER_NAME}, {SENDER_ROLE}

🔑 CREDENCIALES
- Meta (IG + FB): {STATUS}
- TikTok: {STATUS}
- Telegram: {STATUS}

¿Todo correcto? (sí / corregir algo)
```

Si el usuario pide corregir algo, volver a la pregunta específica y actualizar.

---

### Fase 8 — Generar archivos de configuración

#### Archivo 1: `.claude/company-context.json`

```json
{
  "company": {
    "name": "{COMPANY_NAME}",
    "industry": "{INDUSTRY}",
    "product": "{PRODUCT}",
    "tone": "{TONE}",
    "location": "{LOCATION}",
    "value_proposition": "{VALUE_PROPOSITION}",
    "platforms": ["{PLATFORM_1}", "{PLATFORM_2}"]
  },
  "icp": {
    "industry_target": "{INDUSTRY_TARGET}",
    "geography": "{GEOGRAPHY}",
    "company_size": "{COMPANY_SIZE}",
    "decision_maker_role": "{DECISION_MAKER_ROLE}"
  },
  "market": {
    "competitors": ["{COMPETITOR_1}", "{COMPETITOR_2}"],
    "commodities": ["{COMMODITY_1}", "{COMMODITY_2}"],
    "trend_topics": ["{TREND_TOPIC_1}", "{TREND_TOPIC_2}"],
    "trend_competitors_yt": ["{@CANAL_YT_1}"],
    "trend_competitors_tt": ["{@USUARIO_TT_1}"]
  },
  "sales": {
    "sender_name": "{SENDER_NAME}",
    "sender_role": "{SENDER_ROLE}"
  },
  "credentials": {
    "meta": "{tiene|necesita_obtener|no_aplica}",
    "tiktok": "{tiene|necesita_obtener|no_aplica}",
    "telegram": "{tiene|necesita_obtener|no_aplica}"
  },
  "initialized_at": "{TIMESTAMP_ISO}",
  "version": "1.0"
}
```

#### Archivo 2: `.env.example`

Generar un `.env.example` con todas las variables necesarias según las plataformas seleccionadas.

```bash
# ============================================================
# Marketing Toolkit — Variables de entorno
# Configurado para: {COMPANY_NAME}
# Fecha: {FECHA}
# ============================================================

# --- ANTHROPIC (requerido) ---
ANTHROPIC_API_KEY=sk-ant-...

# --- TELEGRAM (requerido para notificaciones) ---
TELEGRAM_BOT_TOKEN=          # Obtener con @BotFather en Telegram
TELEGRAM_CHAT_ID=            # ID del chat donde recibirás alertas

# --- CONTEXTO DE EMPRESA (requerido) ---
COMPANY_NAME={COMPANY_NAME}
INDUSTRY={INDUSTRY}
SENDER_NAME={SENDER_NAME}
SENDER_ROLE={SENDER_ROLE}

{SI INSTAGRAM O FACEBOOK EN PLATAFORMAS}
# --- META (Instagram + Facebook) ---
INSTAGRAM_ACCESS_TOKEN=      # Token de larga duración (60 días)
INSTAGRAM_BUSINESS_ACCOUNT_ID=
FACEBOOK_ACCESS_TOKEN=       # Mismo token de larga duración
FACEBOOK_PAGE_ID=
FACEBOOK_APP_ID=             # Para verificar expiración del token
FACEBOOK_APP_SECRET=         # Para verificar expiración del token
# Guía: https://developers.facebook.com/docs/instagram-api/getting-started

{SI TIKTOK EN PLATAFORMAS}
# --- TIKTOK ---
TIKTOK_ACCESS_TOKEN=         # Token OAuth 2.0 con scope video.publish (dura 24h)
TIKTOK_OPEN_ID=              # open_id del usuario (se obtiene en el auth flow)
# Guía: https://developers.tiktok.com/ → Crear app → Content Posting API

# --- TREND ANALYSIS (YouTube + TikTok) ---
YOUTUBE_API_KEY=             # Google Cloud Console → YouTube Data API v3 (gratuita)
TREND_TOPICS={TREND_TOPICS_DEL_USUARIO}
TREND_COMPETITORS_YT={TREND_COMPETITORS_YT_DEL_USUARIO}  # opcional
TREND_COMPETITORS_TT={TREND_COMPETITORS_TT_DEL_USUARIO}  # opcional
TREND_LOOKBACK_DAYS=7
TREND_TOP_N=10
```

#### Archivo 3: Actualizar `CLAUDE.md` del proyecto

Si existe un `CLAUDE.md` en el directorio raíz, agregar o actualizar la sección de contexto:

```markdown
## Contexto de empresa (generado por /init)

Esta instancia del toolkit está configurada para:

- **Empresa**: {COMPANY_NAME}
- **Sector**: {INDUSTRY}
- **Producto**: {PRODUCT}
- **Tono de comunicación**: {TONE}
- **Ubicación**: {LOCATION}
- **Plataformas activas**: {PLATFORMS}

### Cliente ideal (ICP)
- **Sector objetivo**: {INDUSTRY_TARGET}
- **Geografía de prospectos**: {GEOGRAPHY}
- **Tamaño de empresa**: {COMPANY_SIZE}
- **Decisor de compra**: {DECISION_MAKER_ROLE}

### Equipo comercial
- **Vendedor**: {SENDER_NAME} — {SENDER_ROLE}

### Commodities a monitorear
{COMMODITIES_LIST}

### Competidores
{COMPETITORS_LIST}
```

---

### Fase 9 — Siguiente paso

Mostrar resumen de lo generado y preguntar qué hacer a continuación:

```
✅ Configuración completada. Generé estos archivos:

📄 .claude/company-context.json — contexto para todos los agentes
📄 .env.example — plantilla de variables de entorno con comentarios
📄 CLAUDE.md — actualizado con el contexto de {COMPANY_NAME}
📁 .claude/brand-images/products/ — catálogo de productos con imágenes de referencia
   ├── product-catalog.json — índice de todos los productos
   {PARA_CADA_PRODUCTO:}
   └── {product_slug}/product-info.json {+ ref-N.jpg si subiste fotos}

---
```

Si alguna credencial tenía estado `necesita_obtener`, mostrar guías específicas:

```
{SI META NECESITA CREDENCIALES}
📌 Para Meta (Instagram + Facebook):
1. Ve a https://developers.facebook.com/
2. Crea una app tipo "Business"
3. Agrega el producto "Instagram Graph API"
4. Genera un token de larga duración (60 días) desde el Explorador de API
5. Guarda INSTAGRAM_ACCESS_TOKEN, INSTAGRAM_BUSINESS_ACCOUNT_ID, FACEBOOK_PAGE_ID
6. Activa la renovación automática con /setup-check --tokens

{SI TIKTOK NECESITA CREDENCIALES}
📌 Para TikTok:
1. Ve a https://developers.tiktok.com/
2. Crea una app con product: "Content Posting API"
3. Agrega scopes: video.publish
4. Completa el OAuth flow para obtener access_token + open_id
5. Guarda TIKTOK_ACCESS_TOKEN y TIKTOK_OPEN_ID

{SI TELEGRAM NECESITA CREDENCIALES}
📌 Para Telegram:
1. Abre Telegram y busca @BotFather
2. Envía /newbot — elige nombre y username para tu bot
3. Guarda el token que te envía (TELEGRAM_BOT_TOKEN)
4. Abre tu chat con el bot y envía un mensaje
5. Ve a: https://api.telegram.org/bot{TOKEN}/getUpdates
6. Copia el "chat" → "id" (TELEGRAM_CHAT_ID)
```

Finalmente, ofrecer ejecutar el check de credenciales:

```
¿Quieres que ejecute /setup-check ahora para verificar que todo
esté conectado correctamente?

(s / no)
```

Si responde sí → ejecutar `/setup-check`
Si responde no → terminar con mensaje de éxito

---

## Output final del comando

```json
{
  "initialized": true,
  "company": "{COMPANY_NAME}",
  "platforms": ["{PLATFORM_1}", "{PLATFORM_2}"],
  "products": [
    {
      "slug": "{PRODUCT_SLUG}",
      "name": "{PRODUCT_NAME}",
      "has_reference_images": true,
      "reference_images_count": 2
    }
  ],
  "files_generated": [
    ".claude/company-context.json",
    ".env.example",
    "CLAUDE.md (actualizado)",
    ".claude/brand-images/products/product-catalog.json",
    ".claude/brand-images/products/{slug}/product-info.json"
  ],
  "credentials_pending": ["{PLATAFORMA_SIN_CREDENCIALES}"],
  "setup_check_run": true,
  "initialized_at": "{TIMESTAMP_ISO}"
}
```

---

## Notas importantes

- **El archivo `.env.example` nunca contiene valores reales** — solo nombres de variables con comentarios
- **`company-context.json` es el archivo central** que todos los skills leen para contexto
- Si ya existe un `company-context.json`, preguntar: "¿Quieres actualizar la configuración existente o crear una para otra empresa?"
- El comando NO crea el `.env` — eso lo hace el usuario copiando `.env.example` y llenando los valores
- Si el usuario dice "no sé" en alguna pregunta sobre commodities o competidores, registrar como lista vacía `[]`
