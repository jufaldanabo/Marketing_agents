# Skill: generate-image-prompt

**Propósito**: Genera prompts optimizados para herramientas de IA generativa de imágenes,
basados en el contenido del post y la identidad visual de la empresa.
**Modelo**: `claude-sonnet-4-6`
**Usado por**: `publisher-agent.md`, `/publish-today`

---

## Por qué este skill es crítico

Instagram requiere imagen para publicar en feed. Sin imagen, el Agente Publicador
solo puede publicar en Facebook. Este skill cierra ese gap generando el prompt
necesario para crear la imagen con Midjourney, DALL-E, Adobe Firefly u otras herramientas.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `post_content` | dict | Output del skill generate-b2b-content | `{"caption": "...", "hashtags": [...]}` |
| `topic` | string | Tema del post | "telas recicladas sostenibles" |
| `industry` | string | Sector industrial | "textil" |
| `brand_style` | string | Estilo visual de la marca | "profesional, colores tierra, minimalista" |
| `tool` | enum | Herramienta de destino | `midjourney` / `dalle` / `firefly` / `stable-diffusion` / `generic` |
| `format` | enum | Formato de la imagen | `square` (1:1) / `portrait` (4:5) / `landscape` (16:9) |

## Especificaciones por plataforma

| Plataforma | Formato recomendado | Resolución mínima |
|---|---|---|
| Instagram Feed | 1:1 (cuadrado) o 4:5 (portrait) | 1080x1080 px |
| Instagram Stories | 9:16 (vertical) | 1080x1920 px |
| Facebook Feed | 1:1 o 16:9 | 1200x630 px |
| LinkedIn | 1.91:1 | 1200x627 px |

## Prompt de generación para Claude

```
SYSTEM:
Eres un director de arte especializado en marketing B2B y fotografía comercial.
Generas prompts de imagen que producen resultados profesionales y relevantes para negocios.
Conoces las diferencias de sintaxis entre herramientas de IA generativa.
Nunca sugieres imágenes con texto integrado (las IAs generativas no manejan texto bien).

USER:
Genera un prompt de imagen para este post de redes sociales B2B:

CONTENIDO DEL POST:
{POST_CONTENT}

CONTEXTO:
- Empresa: {COMPANY_NAME}
- Sector: {INDUSTRY}
- Tema: {TOPIC}
- Estilo visual de la marca: {BRAND_STYLE}
- Herramienta destino: {TOOL}
- Formato: {FORMAT}

La imagen debe:
1. Reforzar el mensaje del post sin necesitar texto explicativo
2. Verse profesional y apropiada para audiencia B2B
3. Evitar clichés de stock (apretones de manos, gente sonriendo genérica)
4. Usar composición limpia y bien iluminada
5. NO incluir texto, logos ni marcas (se agregan por separado)

Devuelve JSON:
{
  "tool": "{TOOL}",
  "format": "{FORMAT}",
  "main_prompt": "el prompt principal optimizado para {TOOL}",
  "negative_prompt": "lo que debe evitar (para herramientas que lo soporten)",
  "style_modifiers": ["modificador1", "modificador2"],
  "alternative_concepts": [
    "concepto alternativo 1 si el principal no funciona",
    "concepto alternativo 2"
  ],
  "subject_description": "descripción en español de qué debería mostrar la imagen",
  "photography_notes": "tipo de fotografía, ángulo, iluminación recomendada"
}
```

## Sintaxis por herramienta

### Midjourney
```
[descripción detallada], [estilo fotográfico], [iluminación], [composición],
professional photography, commercial photography, high quality,
--ar 1:1 --v 6 --style raw --q 2
```
- Separar conceptos con comas
- Parámetros al final: `--ar` (aspect ratio), `--v 6` (versión), `--style raw` (menos artístico)
- Negative prompt: `--no text, logos, watermarks, people looking at camera`

### DALL-E 3 (via API o ChatGPT)
```
Professional commercial photograph of [descripción].
[Estilo]: [detalles de iluminación y composición].
[Ambiente]: [contexto y atmósfera].
No text, no logos, no watermarks.
```
- Oraciones completas funcionan mejor
- Ser muy específico en la descripción
- Mencionar explícitamente lo que NO debe aparecer

### Adobe Firefly
```
[descripción], [estilo fotográfico], [iluminación], professional,
commercial photography, high resolution, clean background
```
- Similar a Midjourney pero sin parámetros especiales
- Funciona bien con referencias de estilo ("editorial photography", "product photography")
- Negative prompt en el campo separado de la interfaz

### Stable Diffusion
```
(professional commercial photograph:1.3), [descripción],
(studio lighting:1.2), (high quality:1.4), (8k:1.2),
masterpiece, sharp focus, detailed
Negative: text, watermark, logo, low quality, blurry, distorted
```
- Usar pesos con paréntesis `(concepto:peso)`
- Negative prompt es clave para calidad

### Generic (cualquier herramienta)
```
Professional B2B commercial photograph: [descripción].
Style: [estilo]. Lighting: [iluminación]. Composition: [composición].
No text, logos or watermarks. High quality, clean, professional.
```

## Conceptos visuales por industria

| Industria | Conceptos que funcionan bien |
|---|---|
| Textil / Moda | Close-up de texturas de tela, maquinaria industrial elegante, paletas de color ordenadas, muestras de material |
| Manufactura | Planta industrial limpia y moderna, maquinaria de precisión, control de calidad, materias primas ordenadas |
| Tecnología | Interfaces limpias en pantallas, hardware en ambiente oscuro con luces LED, equipo técnico trabajando |
| Alimenticio | Ingredientes frescos, proceso de producción higiénico, empaque premium, materias primas naturales |
| Construcción | Materiales de construcción de calidad, obra en progreso con perspectiva arquitectónica, herramientas profesionales |
| Logística | Almacenes ordenados, camiones en ruta, sistemas de trazabilidad, mapas de rutas |
| Financiero | Gráficos en pantallas de escritorio, reuniones ejecutivas formales, documentos bien organizados |

## Output esperado

```json
{
  "tool": "midjourney",
  "format": "square",
  "main_prompt": "Close-up macro photograph of recycled fabric texture, GOTS certification tag visible, earthy tones, natural cotton fibers detail, studio lighting, white clean background, professional product photography, commercial quality --ar 1:1 --v 6 --style raw --q 2",
  "negative_prompt": "--no text, watermarks, logos, people, busy backgrounds, synthetic looking",
  "style_modifiers": ["macro photography", "studio lighting", "clean background", "earthy tones"],
  "alternative_concepts": [
    "Aerial view of sorted recycled fabric rolls in a modern textile factory, organized by color",
    "Hands of textile worker examining sustainable fabric quality, blurred factory background"
  ],
  "subject_description": "Textura de close-up de tela reciclada con etiqueta de certificación GOTS visible, tonos tierra, fondo blanco limpio",
  "photography_notes": "Macro photography, luz de estudio difusa desde arriba, fondo blanco o neutro, alta definición de textura"
}
```

## Flujo de uso con el Agente Publicador

```
1. /publish-today genera el contenido del post
2. Este skill genera el prompt de imagen
3. Usuario usa el prompt en Midjourney/DALL-E/Firefly
4. Usuario sube la imagen generada y proporciona la URL
5. /publish-today publica el post con esa URL de imagen
```

Si el usuario no tiene herramienta de generación de imágenes, ofrecer alternativas:
- Unsplash / Pexels (fotos stock gratuitas): buscar con `{TEMA} {INDUSTRIA} professional`
- Canva (crear imagen con texto): plantilla de post con la cita del caption
- Fotografía propia: usar el `photography_notes` como guía para la sesión
