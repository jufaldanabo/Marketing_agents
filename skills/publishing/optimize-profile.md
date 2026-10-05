---
name: optimize-profile
description: Analyzes current social profile (bio, profile picture, link-in-bio, highlights, action button) and proposes optimized versions aligned with the client's brief objectives and brand kit. Returns a diff-style proposal for human approval before applying any changes.
allowed-tools: [Read, Write, WebFetch, Bash]
model: claude-opus-4-7
---

# Skill: optimize-profile

**Propósito**: Optimizar los elementos del perfil social del cliente (bio, foto, enlace, destacadas, botón de acción) para alinear con los objetivos del brief y la identidad del brand kit.

**Fase del flujo de agencia**: **2 — Marca** (optimización de perfiles)

---

## Cuándo invocar

- Después de `/audit` si detectó bio subóptima
- Al terminar `/brand-kit new` si el usuario quiere aplicar la identidad a los perfiles
- Como parte del command `/optimize-profiles`
- Cuando `brief.objectives` cambie significativamente (ej. de awareness a leads → la bio debe cambiar)

---

## Inputs requeridos

| Input | Fuente | Descripción |
|---|---|---|
| `brief` | `_core/load-brief` | Para objetivos, propuesta de valor, buyer persona |
| `brand_kit` | `_core/load-brand-kit` | Para voz, tono, personalidad |
| `platform` | argumento | `instagram` / `facebook` / `tiktok` / `linkedin` |
| `current_profile` | fetch | Estado actual del perfil |

---

## Pipeline

### Paso 1 — Fetch del perfil actual

**Instagram**:
```bash
GET /v18.0/{IG_ACCOUNT_ID}?fields=username,name,biography,profile_picture_url,website,followers_count
GET /v18.0/{IG_ACCOUNT_ID}/stories?fields=... (destacadas)
```

**Facebook**:
```bash
GET /v18.0/{PAGE_ID}?fields=name,about,description,category,website,phone,emails,cover,picture
```

**TikTok**:
```bash
GET /v2/user/info/?fields=open_id,username,bio_description,profile_image_url
```

**LinkedIn**: fetch público del perfil de empresa.

### Paso 2 — Analizar vs criterios de optimización

Para cada elemento, chequear:

**BIO / ABOUT**
- [ ] ¿Comunica propuesta de valor en primera línea?
- [ ] ¿Es escaneable (no párrafo denso)?
- [ ] ¿Tiene CTA claro al final?
- [ ] ¿Usa emojis estratégicamente (según `brand_kit.content_voice.emoji_usage`)?
- [ ] ¿Menciona a quién sirve (buyer_persona)?
- [ ] ¿Dirige al link-in-bio?
- [ ] ¿Longitud apropiada? (IG: 150 chars; FB: más flexible; TikTok: 80 chars)

**FOTO DE PERFIL**
- [ ] ¿Logo o imagen clara, legible en tamaño pequeño?
- [ ] ¿Fondo coherente con `brand_kit.colors`?
- [ ] ¿Reconocible al scrolleo?

**LINK IN BIO**
- [ ] ¿Es un link estratégico (no solo home del sitio)?
- [ ] ¿Alineado con `brief.objectives.primary`?
  - leads → formulario / WhatsApp
  - sales → tienda / producto hero
  - awareness → página de historia / portfolio

**DESTACADAS (IG)** — mínimo 3-5
- [ ] ¿Nombres claros (no "📷 1", "📷 2")?
- [ ] ¿Covers coherentes con `brand_kit`?
- [ ] ¿Cubren funnel: Who We Are, Products, FAQ, Testimonials, Contact?

**BOTÓN DE ACCIÓN**
- IG: Mensaje / Email / Llamar / Dirección — ¿cuál sirve al objetivo?
- FB: Shop Now / Contact Us / Learn More / Send Message
- Si `brief.sales.contact_channels` incluye `whatsapp` → configurar WhatsApp button

### Paso 3 — Generar propuesta optimizada

Para cada elemento problemático, generar la versión optimizada aplicando:
- `brand_kit.prompt_injection.content_prefix/suffix`
- `brand_kit.content_voice.forbidden_words` (NO usar)
- `brand_kit.content_voice.signature_phrases` (considerar incorporar)
- `brief.company.value_proposition`
- `brief.objectives.primary` (determina CTA)
- `brief.buyer_persona` (determina lenguaje)

### Paso 4 — Formato diff

Devolver propuesta estructurada:

```markdown
# PROPUESTA DE OPTIMIZACIÓN DE PERFIL — {platform}

## BIO ACTUAL
```
{bio_actual}
```
**Score**: 4/10
**Problemas**: sin CTA, no menciona a quién sirve, muy denso

## BIO PROPUESTA (variante A - focus leads)
```
{bio_optimizada}
```
**Mejoras**:
- ✅ Primera línea = propuesta de valor en 1 frase
- ✅ Menciona buyer persona (fabricantes textiles)
- ✅ CTA al final: "DM 'quiero cotizar' 📩"
- ✅ 142 chars (dentro de 150)

## BIO PROPUESTA (variante B - focus awareness)
```
...
```

---

## FOTO DE PERFIL
Actual: {descripción breve}
Veredicto: {OK | optimizar}
Si optimizar: sugerencias concretas (ej. "logo centrado sobre fondo {brand_kit.colors.background}")

---

## LINK IN BIO
Actual: {url}
Alineación con objetivo "{brief.objectives.primary}": {alto/medio/bajo}
Sugerencia: {url o acción propuesta}

---

## DESTACADAS (si IG)
Actuales: {count} ({listar nombres})
Propuesta de 5 destacadas:
1. "Nosotros" — historia + propuesta
2. "Productos" — hero del catálogo
3. "Clientes" — testimonios
4. "FAQ" — preguntas frecuentes
5. "Contacto" — cómo cotizar / WhatsApp

Covers sugeridos: aplicar `brand_kit.colors.primary` + icono simple

---

## BOTÓN DE ACCIÓN
Actual: {botón}
Objetivo del brief: {leads}
Botón sugerido: Message con WhatsApp configurado al número {inferir}
```

### Paso 5 — Devolver al invocador

```json
{
  "ok": true,
  "platform": "instagram",
  "proposal_path": ".claude/state/profile-optimization/{YYYY-MM-DD}-instagram.md",
  "elements_optimized": ["bio", "link", "highlights", "action_button"],
  "score_before": 4.2,
  "score_after_estimated": 8.5,
  "requires_human_action": true,
  "action_instructions": "Las APIs de Meta e Instagram NO permiten modificar bio/foto programáticamente. El cliente debe aplicar los cambios desde la app o Meta Business Suite siguiendo las instrucciones del archivo generado."
}
```

---

## Notas importantes

1. **Este skill NO modifica el perfil automáticamente** — las APIs de Meta/TikTok no permiten updates programáticos del perfil (bio, foto, destacadas). Solo genera la propuesta.
2. **Siempre genera mínimo 2 variantes de bio** para que el cliente elija según mood.
3. **El invocador debe pasar por aprobación humana** vía `_core/telegram-approval` antes de que el cliente aplique.
4. **TikTok**: la bio tiene solo 80 chars y permite links solo en ciertas regiones — ajustar propuesta.
5. **LinkedIn**: si es perfil de empresa, el optimizador también sugiere ajustes a tagline + about section.
