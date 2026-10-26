---
name: generate-image-ai
description: Genera (create) o edita (edit) imágenes de producto para redes sociales con fal.ai google/nano-banana-2.1, adaptadas a la industria de la empresa mediante industry-profile.json. En edit usa SIEMPRE la imagen entregada por el usuario y encadena operaciones (quitar fondo, contexto profesional, resaltar, slogan). Devuelve una URL pública lista para Instagram/Facebook/TikTok.
allowed-tools: [Read, Write, Bash]
model: claude-opus-4-7
---

# Skill: generate-image-ai (v2)

Produce una imagen publicitaria para redes sociales a partir del contexto de la empresa,
el perfil de su industria y la petición del día. Tiene dos intenciones separadas:

| intent | Qué hace | Imagen de entrada |
|---|---|---|
| `create` | Genera una imagen nueva desde cero | Ninguna obligatoria. Las fotos del catálogo se usan solo como **referencia de fidelidad** del producto (opcional, máx. 3) |
| `edit` | Transforma una foto que el usuario entrega | `input_image` **obligatoria**. El producto de esa foto es el protagonista y no se altera |

Los prompts son **conversacionales, en español, en primera persona**: suenan como el dueño
de la empresa pidiéndole la imagen a un fotógrafo o a un diseñador. Nunca en inglés,
nunca como instrucción técnica de stock photo. google/nano-banana-2.1 responde mejor a este estilo.

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `FAL_KEY` | API key de fal.ai (https://fal.ai → Dashboard → API Keys) |

---

## Inputs del skill

```
intent            → "create" | "edit"   (si falta, se infiere en Paso 0)
input_image       → ruta local o URL de la foto a editar (obligatoria en edit, ignorada en create)
operations        → lista ordenada, solo en edit. Valores: remove_background | recontext | highlight | slogan
                    Default edit: ["remove_background", "recontext", "highlight"]
topic             → Tópico del post del día
category          → Tipo de tópico: producto | tip | caso_exito | detras_escena | tendencia | fecha_especial | lanzamiento
company_name      → Nombre de la empresa
industry          → Sector (texto libre, ej. "panadería artesanal")
location          → Ciudad/país (o null)
special_date      → Fecha especial (o null)
platform          → instagram_feed (4:5) | instagram_square (1:1) | story (9:16) | tiktok (9:16) | facebook (1.91:1)
product_slug      → Producto del catálogo (o null → auto-detectar por topic/category)
slogan            → Texto corto a colocar (o null). Máximo 5 palabras
slogan_mode       → "overlay" (default, se pinta con código) | "in_model" (lo escribe el modelo)
zona_libre        → "superior_derecha" | "superior_izquierda" | "inferior" | "centro_superior" (default: superior_derecha)
```

Archivos de contexto (generados/aprobados en `/init`):

```
.claude/brand-images/brand-style.json                      → estilo visual de marca (o null)
.claude/brand-images/industry-profile.json                 → perfil de la industria (ver esquema abajo)
.claude/brand-images/products/product-catalog.json         → catálogo con keywords y default_product
.claude/brand-images/products/{slug}/product-info.json     → technical_description aprobada
.claude/brand-images/products/{slug}/*.jpg|png|webp        → fotos de referencia
```

---

## Reglas fundamentales — no negociables

> **🔒 El output es siempre el resultado del modelo.** Nunca se publica un archivo crudo.
> En `edit` sí se usa la foto del usuario como entrada, pero lo que se publica es la imagen
> editada (sin fondo, con contexto, etc.), nunca `input_image` tal cual.

> **🔒 El producto no se inventa ni se altera.** En `edit`, el producto de `input_image`
> conserva forma, color, textura, logo y etiquetas. Solo cambia lo que está alrededor.
> En `create`, el producto se describe con la `technical_description` aprobada, nunca con
> términos genéricos del sector.

> **🔒 Todo prompt está anclado a la industria.** El entorno, los props, la iluminación y la
> paleta salen de `industry-profile.json`. Una zapatería genera en un almacén de calzado; una
> panadería, con hornos y vitrinas; aunque el usuario no lo pida.

> **🔒 Idioma del prompt: español, primera persona, conversacional.** Si el prompt contiene
> "Professional product photography", "neatly arranged", "warm lighting" → está mal, regenerar.

---

## Esquema de `industry-profile.json`

Lo genera el agente en `/init` a partir de `industry` y lo aprueba el usuario. Si no existe
al ejecutar este skill, el agente lo genera en el momento con este esquema, lo guarda y avisa.

```json
{
  "industria": "panadería artesanal",
  "entorno_principal": "interior de una panadería artesanal con vitrina de vidrio y mostrador de madera",
  "entornos_alternativos": {
    "trabajo": "mesa de amasado con harina espolvoreada y horno de leña al fondo",
    "exhibicion": "estante de madera con panes y canastas de mimbre",
    "premium": "mostrador de mármol claro con luz de mañana",
    "cliente": "mesa de cafetería con taza de café y servilleta de tela"
  },
  "props": ["bandejas con pan recién horneado", "vitrina con croissants", "canastas de mimbre", "paño de lino", "horno al fondo"],
  "superficies": ["madera cálida", "mármol claro", "lino crudo"],
  "iluminacion": "luz cálida dorada de mañana, sensación de recién horneado",
  "paleta": "dorados, marrones tostados, crema, toques terracota",
  "ambiente": "acogedor, artesanal, familiar",
  "evitar": ["plástico", "ambiente clínico o frío", "producto quemado", "comida de aspecto industrial", "manos o caras deformes"]
}
```

Ver `industry-profile.example.json` para panadería, zapatería y fábrica textil.

---

## Paso 0 — Determinar intención y fuente de la imagen

**0.1 — Inferir `intent` si no vino explícito:**

| Señal en la petición | intent |
|---|---|
| Viene una imagen adjunta o `input_image` ≠ null | `edit` |
| Verbos: "quítale el fondo", "mejora esta foto", "ponle un slogan a esta", "edita", "cambia el fondo de" | `edit` |
| Verbos: "créame", "genera", "quiero una imagen de", "necesito una foto para el post de" sin imagen adjunta | `create` |
| Ambiguo | **Preguntar al usuario**. Es más barato que generar lo equivocado |

**0.2 — Validar la fuente:**

- `intent == edit` y `input_image == null` → detenerse y pedir la imagen. **No** ir al catálogo a buscar una.
- `intent == edit` y `input_image` existe → `SOURCE_IMAGE = input_image`. Las fotos del catálogo no se usan.
- `intent == create` → `SOURCE_IMAGE = null`. Continuar con 0.3 para referencias opcionales.

**0.3 — Seleccionar producto del catálogo (ambos modos, para la ficha técnica):**

```bash
cat .claude/brand-images/products/product-catalog.json 2>/dev/null
```

1. Si `product_slug` vino explícito → usarlo.
2. Si no, comparar palabras clave de `topic` + `category` con `keywords` de cada producto.
3. Un solo producto → usarlo. Varios sin coincidencia → `default_product`.
4. Sin catálogo → `PRODUCT_SLUG = null`.

**0.4 — Referencias de fidelidad (solo `create`):**

```bash
ls .claude/brand-images/products/$PRODUCT_SLUG/ 2>/dev/null | grep -E "\.(jpg|jpeg|png|webp)$" | head -3
```

Hasta 3 fotos → `REFERENCE_IMAGES`. Se pasan al modelo como guía visual del producto
(para que el zapato generado se parezca al zapato que se vende), **no** como imagen a editar.
Sin fotos → text-to-image puro.

---

## Paso 1 — Verificar FAL_KEY

```bash
[ -f .env ] && export $(grep -v '^#' .env | xargs)
[ -n "$FAL_KEY" ] && echo "ok" || echo "none"
```

Si `none` → ir a Paso 8 (error).

---

## Paso 2 — Cargar contexto

```bash
cat .claude/brand-images/brand-style.json 2>/dev/null
cat .claude/brand-images/industry-profile.json 2>/dev/null
cat .claude/brand-images/products/$PRODUCT_SLUG/product-info.json 2>/dev/null
```

- `PRODUCT_DESCRIPTION` = `technical_description` del product-info. Si no existe y hay
  `SOURCE_IMAGE` o `REFERENCE_IMAGES` → describir el producto con la herramienta de visión.
  Si no hay nada → null.

  **La ficha técnica debe cubrir cinco campos** (en `/init` se exige; si falta alguno, el
  agente lo completa con visión o pregunta). Sin foto de referencia, este párrafo es lo
  único que evita que el modelo invente un producto parecido:
  1. **Forma y presentación** — "disco plano enrollado sobre núcleo de cartón", "torta redonda sobre base dorada con una porción cortada"
  2. **Dimensiones relativas** — "25–30 cm de diámetro; el ancho del disco es el ancho de la tela"
  3. **Material y acabado** — "algodón mate, no brillante", "ganache brillante, miga húmeda"
  4. **Empaque / soporte** — "envuelta en plástico transparente", "sobre base de cartón dorado"
  5. **No confundir con** — "no es cinta de raso ni grosgrain", "no es torta de cumpleaños ni brownie"
- `PROFILE` = industry-profile.json. Si no existe → generarlo ahora con el esquema de arriba.
- `BRAND_STYLE` = brand-style.json o null.

**2.1 — Seleccionar ambientación desde el perfil según `category`:**

| category | entorno | props (2–3) | superficie | notas |
|---|---|---|---|---|
| producto | `entorno_principal` | `props[0..1]` | `superficies[0]` | fondo suave y difuminado |
| tip | `entornos_alternativos.trabajo` | herramientas del oficio del perfil | `superficies[0]` | ordenado, nunca desordenado |
| caso_exito | `entornos_alternativos.cliente` | `props[1..2]` | `superficies[1]` | luz cálida, transmite confianza |
| detras_escena | `entornos_alternativos.trabajo` | elementos de producción al fondo desenfocados | `superficies[0]` | taller limpio |
| tendencia | fondo minimalista con gradiente sutil | 1 prop | `superficies[1]` | editorial |
| fecha_especial | `entorno_principal` + decoración de `special_date` | `props[0]` + decoración | `superficies[0]` | el producto sigue siendo protagonista |
| lanzamiento | `entornos_alternativos.premium` | ninguno o 1 | `superficies[1]` | luz lateral que destaque detalles |

Guardar como `ENTORNO`, `PROPS`, `SUPERFICIE`, `NOTAS_AMBIENTE`. Siempre usar `PROFILE.iluminacion`,
`PROFILE.paleta` y `PROFILE.evitar`.

**2.2 — Zona libre para texto:** si `slogan != null` → `ZONA_LIBRE` en lenguaje natural
("la esquina superior derecha", "la franja inferior"). Si `slogan == null` → omitir la frase.

**2.3 — Formato:**

| platform | aspect_ratio |
|---|---|
| instagram_feed | 4:5 |
| instagram_square | 1:1 |
| story / tiktok | 9:16 |
| facebook | 16:9 |

---

## Paso 3A — Prompt CREATE

Seguir la plantilla al pie de la letra. No resumir, no convertir a estilo técnico.
Antes de escribir, responder mentalmente: ¿quién soy? ¿qué producto, físicamente? ¿qué tema?
¿qué entorno de mi industria? ¿qué va dónde? ¿qué es el protagonista? ¿qué luz?

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}
{en {LOCATION}}. Necesito una imagen para publicar en redes sociales.

{Si PRODUCT_DESCRIPTION:
Mi empresa fabrica/vende {PRODUCT_DESCRIPTION}.
→ Describir cada producto por su forma física exacta, color, material, presentación
  y tamaño relativo. "Carrete cilíndrico de plástico negro con sesgo azul enrollado",
  no "rollos de colores". "Zapato oxford de cuero marrón con suela de goma y costura
  visible", no "zapatos elegantes".}

{Si REFERENCE_IMAGES: Te adjunto fotos reales del producto para que lo reproduzcas
fielmente: misma forma, color, materiales y detalles. Úsalas como guía, no como
imagen a editar.}

{Si BRAND_STYLE: El estilo visual de mi marca es: {BRAND_STYLE}.}

El tema del post de hoy es: {TOPIC}. {Si SPECIAL_DATE: La ocasión es {SPECIAL_DATE}.}

Quiero una imagen profesional y realista, como tomada por un equipo experto en
fotografía de producto, que muestre {COMPOSICIÓN_EXPLÍCITA: qué producto, dónde:
"a la izquierda", "apilados a la derecha", "al fondo", sobre {SUPERFICIE}}.

La escena es {ENTORNO}, con {PROPS} alrededor, ordenados y ligeramente
desenfocados. {NOTAS_AMBIENTE}. La iluminación es {PROFILE.iluminacion} y la
paleta general {PROFILE.paleta}. El ambiente debe sentirse {PROFILE.ambiente}.

El protagonista absoluto es {ELEMENTO_PROTAGONISTA}. Todo lo demás acompaña
sin opacarlo.

{Si ZONA_LIBRE: Deja {ZONA_LIBRE} despejada, sin objetos ni elementos
importantes, porque voy a colocar un texto ahí.}

{Si slogan_mode == in_model y slogan: Escribe el texto "{SLOGAN}" en {ZONA_LIBRE},
con tipografía limpia y legible, sobre un área lisa, sin tapar el producto.}

Evita que aparezca: {PROFILE.evitar, separados por coma}.
{Si no hay slogan in_model: Sin texto, sin logos, sin marcas de agua.}
```

**Ejemplo (zapatería, category = producto, slogan overlay):**

```
Soy dueño de Calzado Andino, una zapatería en Bogotá, Colombia. Necesito una
imagen para publicar en redes sociales.

Mi empresa vende zapatos de cuero para hombre: un oxford de cuero marrón cognac,
puntera lisa, suela de goma color miel, cordones encerados y costura visible
en el contorno.

El tema del post de hoy es: zapatos para volver a la oficina.

Quiero una imagen profesional y realista, como tomada por un equipo experto en
fotografía de producto, que muestre un par de oxford marrón cognac, uno de pie
y otro ligeramente inclinado mostrando la suela, en el centro de la imagen,
sobre un estante de madera oscura.

La escena es el interior de una tienda de calzado boutique, con filas de cajas
de zapatos y un espejo de piso al fondo, ordenados y ligeramente desenfocados.
Fondo suave y difuminado. La iluminación es luz de showroom limpia y direccional
con sombras suaves, y la paleta general marrones, cognac y madera oscura con
toques crema. El ambiente debe sentirse elegante y confiable.

El protagonista absoluto es el par de zapatos. Todo lo demás acompaña sin opacarlo.

Deja la esquina superior derecha despejada, sin objetos ni elementos
importantes, porque voy a colocar un texto ahí.

Evita que aparezca: pies descalzos, zapatos con proporciones incorrectas,
suelas flotando, cajas desordenadas, ambiente de bodega.
Sin texto, sin logos, sin marcas de agua.
```

→ `PROMPT_CREATE` → Paso 4A.

---

## Paso 3B — Prompts EDIT (por operación)

En `edit` se construye **un prompt por operación**, y cada operación recibe como entrada
la salida de la anterior. Orden canónico: `remove_background` → `recontext` → `highlight` → `slogan`.

**Regla de oro de edición:** nunca decirle al modelo qué HACER con el producto, solo qué
PONER ALREDEDOR. No describir acciones ("muestra el pan siendo cortado"). El producto se queda
exactamente como está en la foto.

### 3B.1 — `remove_background`

No usa prompt. Va a un modelo de segmentación (Paso 4B.1). Salida: PNG con fondo transparente.
Un modelo generativo "reinterpreta" el producto; el segmentador lo deja intacto.

### 3B.2 — `recontext`

```
Soy {dueño/responsable de marketing} de {COMPANY_NAME}, una empresa de {INDUSTRY}
{en {LOCATION}}. Esta es una foto de {PRODUCT_DESCRIPTION_RESUMIDA}
{, ya recortada sin fondo | con un fondo casual que quiero reemplazar}.

Quiero que la vuelvas una foto profesional lista para publicar en las redes
sociales oficiales de la marca, como si la hubiera ambientado un equipo experto
en fotografía de producto.

Mantén el producto exactamente igual: misma forma, color, textura, proporciones,
logo y etiquetas. Solo cambia lo que está alrededor.

Colócalo en {ENTORNO}, sobre {SUPERFICIE}, con {PROPS} alrededor, ordenados y
ligeramente desenfocados. {NOTAS_AMBIENTE}. Que la luz sea {PROFILE.iluminacion},
coherente con la luz que ya tiene el producto, y que el producto proyecte una
sombra de contacto realista sobre la superficie. Paleta general {PROFILE.paleta}.

{Si SPECIAL_DATE: Agrega ambientación de {SPECIAL_DATE} alrededor, sin que
compita con el producto.}

El protagonista es {ELEMENTO_PROTAGONISTA}. Si quedan objetos de la foto original
que no son parte del producto (papeles, cables, objetos de escritorio), remuévelos.

{Si ZONA_LIBRE: Deja {ZONA_LIBRE} despejada, sin objetos, porque voy a colocar
un texto ahí.}

Evita que aparezca: {PROFILE.evitar}. Sin texto, sin logos, sin marcas de agua.
```

### 3B.3 — `highlight`

```
Esta es una foto de {PRODUCT_DESCRIPTION_RESUMIDA} de {COMPANY_NAME}.
Quiero que el producto resalte más, sin cambiarlo: mantén su forma, color,
textura, logo y etiquetas exactamente iguales.

Dale más nitidez y contraste al producto, suaviza y desatura ligeramente el
fondo, agrega una luz de borde sutil que lo separe del fondo y mejora el balance
de color general para que se vea limpio y profesional. No agregues ni quites
objetos. Sin texto, sin logos, sin marcas de agua.
```

### 3B.4 — `slogan`

- `slogan_mode == overlay` (default) → no usa modelo; ir a Paso 5.
- `slogan_mode == in_model`:

```
Esta es una foto de producto de {COMPANY_NAME}. Agrega el texto "{SLOGAN}"
en {ZONA_LIBRE}, con tipografía limpia, {BRAND_STYLE.tipografia | sans-serif moderna},
color {BRAND_STYLE.color_texto | que contraste con el fondo}, legible en pantalla
de celular. El texto no debe tapar el producto ni deformarlo. No cambies nada más
en la imagen.
```

**Ejemplo `recontext` (panadería, foto casual de un pan):**

```
Soy dueño de Pan de Casa, una panadería artesanal en Medellín, Colombia. Esta es
una foto de una hogaza de pan de masa madre de corteza dorada y crujiente con
cortes en cruz, ya recortada sin fondo.

Quiero que la vuelvas una foto profesional lista para publicar en las redes
sociales oficiales de la marca, como si la hubiera ambientado un equipo experto
en fotografía de producto.

Mantén el producto exactamente igual: misma forma, color, textura, proporciones,
logo y etiquetas. Solo cambia lo que está alrededor.

Colócalo en el interior de una panadería artesanal con vitrina de vidrio y
mostrador de madera, sobre una tabla de madera cálida, con un paño de lino y
una canasta de mimbre con otros panes alrededor, ordenados y ligeramente
desenfocados. Fondo suave y difuminado. Que la luz sea luz cálida dorada de
mañana, coherente con la luz que ya tiene el producto, y que el pan proyecte
una sombra de contacto realista sobre la tabla. Paleta general dorados,
tostados y crema.

El protagonista es la hogaza de pan. Si quedan objetos de la foto original
que no son parte del producto, remuévelos.

Deja la franja inferior despejada, sin objetos, porque voy a colocar un texto ahí.

Evita que aparezca: plástico, ambiente clínico o frío, pan quemado, comida de
aspecto industrial. Sin texto, sin logos, sin marcas de agua.
```

---

## Paso 4 — Llamadas a fal.ai

> Construir siempre el payload con Python o `jq` y enviarlo con `-d @payload.json`.
> Nunca meter el prompt ni base64 directamente en la línea de comando: las comillas
> rompen el JSON y una imagen normal supera el límite de argumentos del shell.

> Verificar los nombres de parámetros en la página de cada modelo en fal.ai antes del
> primer uso (`image_urls` como lista, `aspect_ratio`, `output_format`). Los nombres
> `image_size` / `image_url` singular son de la familia FLUX y pueden no aplicar.

**Helper para codificar imágenes locales:**

```bash
to_data_uri() { python3 - "$1" <<'EOF'
import sys, base64, mimetypes
p = sys.argv[1]; m = mimetypes.guess_type(p)[0] or "image/jpeg"
print(f"data:{m};base64," + base64.b64encode(open(p,"rb").read()).decode())
EOF
}
```

### 4A — CREATE

```bash
python3 - <<EOF > payload.json
import json
p = {"prompt": open("prompt_create.txt").read(), "aspect_ratio": "$ASPECT", "num_images": 1}
refs = $REFERENCE_IMAGES_JSON   # lista de data URIs o []
if refs: p["image_urls"] = refs  # con refs → usar endpoint /edit como guía visual
print(json.dumps(p))
EOF
ENDPOINT="google/nano-banana-2.1"; [ -n "$REFS" ] && ENDPOINT="google/nano-banana-2.1/edit"
curl -s -X POST "https://fal.run/$ENDPOINT" -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" -d @payload.json > out.json
```

### 4B — EDIT (encadenado)

`CURRENT=$(to_data_uri "$SOURCE_IMAGE")`. Para cada operación en orden:

**4B.1 `remove_background`** → modelo de segmentación (ej. `fal-ai/birefnet` o `fal-ai/bria/background/remove`):

```bash
jq -n --arg img "$CURRENT" '{image_url: $img}' > payload.json
curl -s -X POST "https://fal.run/fal-ai/birefnet" -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" -d @payload.json > out.json
CURRENT=$(jq -r '.image.url' out.json)
```

**4B.2 `recontext` / 4B.3 `highlight` / 4B.4 `slogan in_model`** → `google/nano-banana-2.1/edit`:

```bash
python3 - <<EOF > payload.json
import json
print(json.dumps({"prompt": open("prompt_${OP}.txt").read(), "image_urls": ["$CURRENT"],
                  "aspect_ratio": "$ASPECT", "num_images": 1}))
EOF
curl -s -X POST "https://fal.run/google/nano-banana-2.1/edit" -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" -d @payload.json > out.json
CURRENT=$(jq -r '.images[0].url' out.json)
```

Al final `IMAGE_URL = CURRENT`.

---

## Paso 5 — Slogan por overlay (default)

Si `slogan != null` y `slogan_mode == overlay`: descargar `IMAGE_URL`, pintar el texto con Pillow
en `zona_libre` usando la fuente y color de `brand-style.json` (fallback: sans-serif bold, blanco con
sombra suave), tamaño ≈ 5–6 % del alto de la imagen, margen 4 %. Subir el resultado al storage
propio (Paso 7) y usar esa URL. Ventajas: ortografía garantizada, fuente de marca, gratis.

---

## Paso 6 — Verificación

Revisar la imagen final con la herramienta de visión. Rehacer (máx. 3 intentos) si:

- Hay defectos: manos/caras deformes, artefactos, texto ilegible.
- **En `edit`: el producto no coincide con `SOURCE_IMAGE`** (forma, color, etiqueta, logo). Es el
  fallo más caro: publicar un producto que no se vende. Comparar lado a lado.
- **El entorno no corresponde a la industria** (zapatos sin tienda, pan sin panadería). Reforzar
  `ENTORNO` y `PROPS` en el prompt y regenerar.
- `ZONA_LIBRE` no quedó despejada y hay slogan → regenerar o mover el texto.
- `IMAGE_URL` no es una URL pública (apunta a ruta local o a `SOURCE_IMAGE`) → la generación no
  terminó, reintentar.

---

## Paso 7 — Guardar resultado

Descargar la imagen final y subirla al storage propio (S3, Cloudinary, Supabase). No depender de
que las URLs de fal.media sean permanentes. Guardar `.claude/posts/images/{FECHA}.json`:

```json
{
  "date": "{FECHA_ISO}",
  "intent": "create | edit",
  "operations": ["remove_background", "recontext", "highlight"],
  "models": ["fal-ai/birefnet", "google/nano-banana-2.1/edit"],
  "product_slug": "{slug} | null",
  "source_image": "{input_image} | null",
  "reference_images": ["..."] ,
  "prompts_used": {"recontext": "...", "highlight": "..."},
  "slogan": "{slogan} | null",
  "slogan_mode": "overlay | in_model",
  "image_url": "https://tu-storage/...",
  "topic": "{TOPIC}", "category": "{CATEGORY}", "platform": "{PLATFORM}"
}
```

---

## Paso 8 — Sin FAL_KEY

```
⚠️  No se encontró FAL_KEY. Configura FAL_KEY=tu_key (https://fal.ai → Dashboard → API Keys).
⛔ No publicar la foto original ni ninguna imagen sin procesar.
```

---

## Output del skill

```json
{
  "success": true,
  "intent": "create | edit",
  "operations": [...],
  "image_url": "https://tu-storage/...",
  "prompts_used": {...},
  "aspect_ratio": "4:5",
  "ready_for_publishing": true
}
```

---

## Guía anti-alucinaciones

| Problema | Causa | Solución |
|---|---|---|
| Entorno genérico, no se nota la industria | Perfil ausente o props vagos | Revisar `industry-profile.json`: `props` concretos y `evitar` específico. El 80 % de la calidad sectorial vive ahí |
| Producto cambiado en edit | Prompt describe acciones o re-describe el producto en detalle | Solo "mantén el producto exactamente igual" + qué poner alrededor. Nunca verbos sobre el producto |
| Producto genérico en create | `technical_description` vaga | Reescribirla con forma, color, material, presentación. Pasar `REFERENCE_IMAGES` |
| Fondo mal recortado | Se usó generativo para quitar fondo | Usar siempre el segmentador en `remove_background` |
| Texto ilegible o mal escrito | Texto generado por el modelo | `slogan_mode: overlay` |
| Luz del producto no coincide con la escena | Recontext sin referencia a la luz original | Frase "coherente con la luz que ya tiene el producto" + sombra de contacto |
| Manos/caras deformes | Escena con personas | Evitar personas salvo que `BRAND_STYLE` lo pida; si las hay, sin manos en primer plano |
