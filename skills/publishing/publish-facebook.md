# Skill: publish-facebook

**Propósito**: Publica contenido en una Página de Facebook via Graph API.
**API**: Facebook Graph API v18.0
**Usado por**: `publisher-agent.md`, `/publish-today`

---

## Cuándo usar este skill

Usar cuando tengas contenido listo para publicar en una Página de Facebook Business.
A diferencia de Instagram, Facebook permite posts de solo texto.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `message` | string | Texto del post (óptimo 300-500 chars) |
| `image_url` | string | URL pública de imagen (opcional pero recomendado) |
| `FACEBOOK_ACCESS_TOKEN` | env | Token de acceso de la página |
| `FACEBOOK_PAGE_ID` | env | ID numérico de la página de Facebook |

## Flujo de publicación

### Post con texto solamente

```
POST https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/feed

Parámetros:
  message       = {TEXTO_DEL_POST}
  access_token  = {FACEBOOK_ACCESS_TOKEN}

Respuesta exitosa:
  { "id": "123456789_987654321" }   ← Formato: PAGE_ID_POST_ID
```

### Post con imagen

```
POST https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/photos

Parámetros:
  url           = {URL_PÚBLICA_DE_LA_IMAGEN}
  message       = {TEXTO_DEL_POST}
  access_token  = {FACEBOOK_ACCESS_TOKEN}

Respuesta exitosa:
  { "id": "987654321", "post_id": "123456789_987654321" }
```

### Post con enlace (link preview)

```
POST https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/feed

Parámetros:
  message       = {TEXTO_DEL_POST}
  link          = {URL_A_COMPARTIR}
  access_token  = {FACEBOOK_ACCESS_TOKEN}
```

## Programar publicación futura

```
POST https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/feed

Parámetros:
  message           = {TEXTO_DEL_POST}
  scheduled_publish_time = {UNIX_TIMESTAMP}  ← ej. 1735689600
  published         = false
  access_token      = {FACEBOOK_ACCESS_TOKEN}
```

## Manejo de errores comunes

| Código | Error | Solución |
|---|---|---|
| 190 | Token expirado | Generar nuevo token de página en Business Suite |
| 200 | Permiso faltante | Agregar `pages_manage_posts` en la app |
| 100 | Contenido duplicado | Facebook rechaza posts idénticos recientes |
| 368 | Contenido bloqueado | Revisar políticas de contenido de Facebook |
| 506 | Contenido duplicado | Modificar ligeramente el texto |

## Verificar post publicado

```
GET https://graph.facebook.com/v18.0/{POST_ID}
  fields=id,message,created_time,permalink_url,shares,reactions.summary(true)
  access_token={FACEBOOK_ACCESS_TOKEN}
```

## Permisos requeridos en Meta App

La app de Facebook debe tener estos permisos aprobados:
- `pages_manage_posts` — publicar en la página
- `pages_read_engagement` — leer métricas y comentarios
- `pages_messaging` — leer mensajes directos

## Output esperado

```
✅ Publicado en Facebook
Post ID: 123456789_987654321
URL: https://www.facebook.com/permalink/php?story_fbid=987654321&id=123456789
Hora: 2026-02-27 09:15:45
```

En caso de error:
```
❌ Error publicando en Facebook
Código: 100
Mensaje: Unsupported post request - Object with ID '...' does not exist
Acción: Verificar que FACEBOOK_PAGE_ID es correcto y que el token tiene acceso a esa página
```

## Mejores prácticas para alcance orgánico

- Publicar entre 9:00-11:00 AM o 1:00-3:00 PM (hora local del público)
- Las imágenes aumentan el alcance orgánico ~2.3x vs solo texto
- Evitar publicar más de 1-2 veces por día (penalización de algoritmo)
- Responder comentarios en las primeras 2 horas mejora el alcance
- Los posts con pregunta al final generan más engagement
