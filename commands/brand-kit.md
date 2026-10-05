---
description: Extrae o actualiza la identidad visual y verbal del cliente a partir de materiales reales (logo, web, Instagram, manual de marca). Invoca al agente brand-guardian.
argument-hint: new | update | show
allowed-tools: [Read, Write, Edit, Bash, Task]
---

# Command: /brand-kit

**Propósito**: Entry point para gestionar `brand-kit.json` — la identidad visual y verbal que todos los skills de generación (`generate-image-ai`, `generate-b2b-content`, `generate-carousel`, etc.) inyectan en sus prompts.

**Principio**: Nunca pedir al cliente códigos hex, nombres de fuentes ni términos técnicos de diseño. El agente `brand-guardian` extrae todo de materiales reales (logo, PDFs, fotos, web).

**Schema**: `skills/_core/schemas/brand-kit.schema.json`

---

## Subacciones

| Acción | Uso |
|---|---|
| `/brand-kit new` | Extraer brand kit desde materiales del cliente (logos, web, IG, PDFs) |
| `/brand-kit update` | Refinar paleta, voz, prompt injection específicos |
| `/brand-kit show` | Previsualizar brand kit activo |

Si se invoca sin argumento y existe `brand-kit.json` → `show`; si no, sugerir `/brand-kit new`.

---

## Acción: `new`

### Paso 1 — Precondiciones

1. Invocar `_core/load-brief` → si no hay brief, abortar y sugerir `/briefing new`
2. Si ya existe `.claude/brand-kit.json`:
   ```
   Ya existe un brand kit para "{brand_name}". ¿Qué quieres hacer?
     1. Reemplazar completamente
     2. Actualizar campos específicos → /brand-kit update
     3. Cancelar
   ```

### Paso 2 — Recopilar materiales

Preguntar al usuario qué materiales tiene disponibles. Aceptar CUALQUIER combinación:

```
Para extraer la identidad de marca de {brand_name}, dime qué materiales tienes.
Puedes compartir uno, varios o todos:

  🌐 URL de la web del cliente
  📱 Handle de Instagram (@ejemplo)
  📱 Handle de TikTok (@ejemplo)
  🖼️ Logo (arrastra el archivo)
  📸 Fotos de producto o del negocio (arrastra 3-10 archivos)
  📄 Manual de marca (PDF)
  🎨 Presentación de marca (PPTX)
  ✏️ Notas o preferencias verbales ("somos cálidos, artesanales...")

Comparte lo que tengas. Si no tienes materiales, puedo generar una
propuesta inicial basada en benchmarks del sector.
```

Para archivos locales, guardarlos en `.claude/brand-images/sources/` conservando nombres originales.

### Paso 3 — Delegar al agente brand-guardian

Usar la tool `Task` con `subagent_type: brand-guardian`:

```
Prompt al brand-guardian:

Extrae la identidad visual y verbal para el cliente del brief activo.

Materiales disponibles:
- URL web: {si hay}
- Instagram: {si hay}
- TikTok: {si hay}
- Archivos locales: {rutas de los archivos subidos}
- Notas del cliente: {si hay}

Genera un brand-kit.json que cumpla con el schema brand-kit.schema.json
y guárdalo en .claude/brand-kit.json.

Asegura que prompt_injection.image_prefix, image_suffix, content_prefix y
content_suffix estén completos — son críticos para la coherencia downstream.
```

El agente opera en su propio contexto (subagent), descarga/analiza materiales con `WebFetch` y Claude Vision, y devuelve el resultado.

### Paso 4 — Mostrar preview al usuario

Cuando el agente termine, mostrar un resumen visual:

```
🎨 BRAND KIT EXTRAÍDO — {brand_name}

🎨 Paleta
  Primario: ████ {colors.primary}
  Secundario: ████ {colors.secondary}
  Fondo: ████ {colors.background}
  {palette_description}

✍️ Tipografía
  Títulos: {typography.headings_font}
  Cuerpo: {typography.body_font}

📸 Estilo visual
  Fotografía: {visual_identity.photography_style}
  Mood: {visual_identity.mood}
  Evitar: {visual_identity.avoid.join(", ")}

🗣️ Voz
  Personalidad: {content_voice.personality}
  Tono: {content_voice.tone_spectrum}
  Emojis: {content_voice.emoji_usage}
  Prohibido: {content_voice.forbidden_words.join(", ")}

Confianza: {confidence}
Fuentes: {sources.join(", ")}

¿Es correcto? (sí / ajustar X / regenerar)
```

### Paso 5 — Confirmación o ajustes

- Si confirma → mantener `.claude/brand-kit.json`, mensaje de éxito
- Si pide ajustes puntuales → invocar `/brand-kit update` con el campo específico
- Si pide regenerar → volver a Paso 3 con instrucciones nuevas

### Paso 6 — Siguiente paso

```
✅ Brand kit guardado en .claude/brand-kit.json

Siguientes pasos:
  • Generar un post de prueba: /publish-today --dry-run
  • Planificar el mes: /content-calendar
  • Ver todo el toolkit: /setup-check
```

---

## Acción: `update`

Permite editar campos específicos sin regenerar todo:

```
¿Qué quieres ajustar?

  1. colors — paleta
  2. typography — fuentes
  3. visual_identity — estilo fotográfico, mood
  4. content_voice — personalidad, tono, emojis, palabras prohibidas
  5. prompt_injection — fragmentos que se inyectan en generación
  6. logo — descripción, uso
  7. platform_adaptations — ajustes por plataforma
```

Para cada campo:
1. Mostrar valor actual
2. Preguntar cambio
3. Validar contra schema
4. Reescribir con `updated_at` nuevo

**Caso especial — update con nuevo material**:
```
/brand-kit update --add-source {ruta-archivo-o-url}
```
Delegar a `brand-guardian` solo con ese nuevo material + brand kit actual → el agente propone diffs.

---

## Acción: `show`

Cargar `.claude/brand-kit.json` y mostrar el preview visual del Paso 4.

Si no existe → sugerir `/brand-kit new`.

---

## Casos de uso del brand-guardian

El agente maneja 5 escenarios internamente:

| Escenario | Materiales | Confidence resultante |
|---|---|---|
| A | Manual de marca (PDF/PPT) | `extracted` |
| B | Web + Instagram | `extracted` |
| C | Solo logo + fotos | `inferred` |
| D | Solo texto, sin materiales | `suggested` |
| E | Múltiples fuentes cruzadas | `extracted` (con cross-validation) |

El campo `confidence` en el output le dice al resto del toolkit cuánto confiar en el brand kit (los commands de publicación pueden pedir re-aprobación extra si `confidence = suggested`).

---

## Output JSON (modo no-interactivo, futuro)

```json
{
  "action": "new|update|show",
  "ok": true,
  "brand_kit_path": ".claude/brand-kit.json",
  "confidence": "extracted",
  "sources": ["web:...", "pdf:...", "logo:logo.png"],
  "warnings": []
}
```

---

## Notas

- `/brand-kit` requiere que `/briefing` ya se haya ejecutado (el brand-guardian lee `client-brief.json` como contexto).
- La extracción puede tomar 30-60s si hay PDFs grandes o muchas imágenes. El agente da feedback de progreso.
- Si el usuario NO tiene materiales, el agente genera una propuesta `confidence: suggested` que debe validar.
- Las imágenes del cliente se guardan en `.claude/brand-images/sources/` para re-análisis futuro sin tener que re-subir.
