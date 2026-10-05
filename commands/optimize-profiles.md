---
description: Analiza y optimiza bio, foto, enlace, destacadas y botón de acción de los perfiles sociales del cliente alineados con objetivos y brand kit. Phase 2 del flujo de agencia.
argument-hint: [platform ig|fb|tt|all]
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /optimize-profiles

**Propósito**: Generar propuestas optimizadas de los elementos del perfil social (bio, foto, link-in-bio, destacadas, botón de acción) alineadas con el brief y el brand kit.

**Fase del flujo de agencia**: **2 — Marca** (optimización de perfiles)

**Skills invocados**: `publishing/optimize-profile`, `_core/load-brief`, `_core/load-brand-kit`, `_core/telegram-approval`

---

## Cuándo ejecutar

- Después de `/brand-kit new` para aplicar identidad fresca
- Después de `/audit` si detectó perfiles subóptimos (score < 7/10)
- Al cambiar `brief.objectives.primary` (ej. de awareness a leads)
- Trimestralmente como mantenimiento

---

## Precondiciones

1. `_core/load-brief` → abortar si no hay brief
2. `_core/load-brand-kit` → warning si falta (usará defaults)
3. `_core/preflight-check --domains meta,anthropic` → necesitamos Meta para fetch de perfiles actuales

---

## Flujo

### Paso 1 — Interpretar argumentos

- `$1` = platform: `ig | fb | tt | linkedin | all` (default `all` = todas las de `brief.company.platforms`)

### Paso 2 — Para cada plataforma seleccionada, invocar skill

Invocar `publishing/optimize-profile` con:
- `platform`: la plataforma actual
- Automáticamente carga brief y brand kit vía skills de `_core/`

El skill genera propuesta estructurada en `.claude/state/profile-optimization/{YYYY-MM-DD}-{platform}.md`.

### Paso 3 — Enviar propuesta a aprobación

Para cada plataforma, invocar `_core/telegram-approval` con:
- `preview_text` = resumen de la propuesta (bio before/after + elementos a cambiar)
- `context` = "Optimización de perfil {platform} para {brand.name}"
- `timeout_seconds` = 600 (10 min)

### Paso 4 — Si aprobado, generar instrucciones de aplicación

Dado que Meta/TikTok NO permiten updates programáticos del perfil, generar `.claude/state/profile-optimization/{YYYY-MM-DD}-{platform}-apply.md`:

```markdown
# INSTRUCCIONES DE APLICACIÓN — {platform}

Para aplicar los cambios aprobados:

## BIO
1. Ir a: {deeplink según plataforma}
2. Reemplazar bio actual por:
```
{bio_aprobada}
```

## LINK IN BIO
1. Nuevo link: {url}

## DESTACADAS (si IG)
1. Crear/renombrar las siguientes destacadas con estos nombres:
   {lista}
2. Para los covers, descargar los archivos generados en .claude/state/profile-optimization/covers/

## BOTÓN DE ACCIÓN
1. Configurar: {botón sugerido}
2. {Instrucciones específicas, ej. "vincular WhatsApp +XX..."}

## CHECKLIST FINAL
- [ ] Bio actualizada
- [ ] Link actualizado
- [ ] Destacadas creadas/renombradas
- [ ] Botón de acción configurado
- [ ] Verificar en móvil que se ve bien
```

Enviar también por Telegram vía `_core/telegram-notify`.

### Paso 5 — Presentar resultado al usuario

```
✅ PROPUESTAS DE OPTIMIZACIÓN GENERADAS

Para cada plataforma procesada:
  📄 Propuesta: .claude/state/profile-optimization/{DATE}-{platform}.md
  📘 Instrucciones de aplicación: {DATE}-{platform}-apply.md
  📊 Score estimado: {before} → {after}

⚠️ Nota: Meta y TikTok no permiten modificar perfiles programáticamente.
   Debes aplicar los cambios manualmente desde la app o Meta Business Suite.
   Las instrucciones están en los archivos generados.

➡️ Siguiente paso sugerido:
   /audit --focus profiles  (en 1-2 semanas, para medir impacto)
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `$1` | enum | `all` | `ig` / `fb` / `tt` / `linkedin` / `all` |

---

## Ejemplos de uso

```
/optimize-profiles
/optimize-profiles ig
/optimize-profiles all
```

---

## Notas

- **Este command NO modifica perfiles automáticamente**. Las APIs de Meta/TikTok no exponen endpoints de edición de perfil. Produce instrucciones ejecutables por el humano.
- Para destacadas de IG, el command puede generar los **covers** como imágenes (invocando `generate-image-ai`) para que el usuario solo las suba.
- Se guardan versiones previas por si se quiere A/B testing (ver `.claude/state/profile-optimization/history/`).
