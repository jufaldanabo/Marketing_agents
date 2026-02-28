# Skill: publish-instagram

**Propósito**: Publica contenido en una cuenta de Instagram Business via Graph API.
**API**: Instagram Graph API v18.0
**Usado por**: `publisher-agent.md`, `/publish-today`

---

## Cuándo usar este skill

Usar cuando tengas contenido listo para publicar en Instagram Business.
Requiere un token de acceso válido y el ID de la cuenta de negocio.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `caption` | string | Texto del post con hashtags (máx 2,200 chars) |
| `image_url` | string | URL pública de la imagen (obligatorio para posts en feed) |
| `INSTAGRAM_ACCESS_TOKEN` | env | Token de acceso de larga duración |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | env | ID numérico de la cuenta de negocio |

## Flujo de publicación

Instagram requiere dos llamadas para publicar:

### Llamada 1 — Crear contenedor de media

```
POST https://graph.facebook.com/v18.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/media

Parámetros:
  image_url     = {URL_PÚBLICA_DE_LA_IMAGEN}
  caption       = {CAPTION_CON_HASHTAGS}
  access_token  = {INSTAGRAM_ACCESS_TOKEN}

Respuesta exitosa:
  { "id": "17841234567890" }   ← Este es el creation_id
```

### Llamada 2 — Publicar el contenedor

```
POST https://graph.facebook.com/v18.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/media_publish

Parámetros:
  creation_id   = {ID_DEL_PASO_ANTERIOR}
  access_token  = {INSTAGRAM_ACCESS_TOKEN}

Respuesta exitosa:
  { "id": "17841234567891" }   ← Este es el post_id publicado
```

## Tipos de contenido soportados

| Tipo | Descripción | Endpoint |
|---|---|---|
| Post con imagen | Una imagen + caption | `/media` con `image_url` |
| Post con video | Video corto + caption | `/media` con `video_url` + `media_type=VIDEO` |
| Carrusel | Múltiples imágenes | Crear children primero, luego contenedor CAROUSEL |
| Reel | Video vertical | `/media` con `video_url` + `media_type=REELS` |

## Manejo de errores comunes

| Código | Error | Solución |
|---|---|---|
| 190 | Token expirado | Renovar token en Meta Business Suite |
| 100 | Parámetro inválido | Verificar formato de image_url (debe ser HTTPS público) |
| 200 | Permiso faltante | Agregar permiso `instagram_content_publish` en la app |
| 10 | No tiene cuenta de negocio | La cuenta debe ser Business o Creator |

## Limitaciones

- **Sin imagen**: Instagram no soporta posts de solo texto en feed. Alternativas:
  - Usar Stories (requiere endpoint diferente)
  - Crear imagen de texto programáticamente
  - Guardar para publicación manual
- **Rate limit**: 25 posts por 24 horas por cuenta
- **Imagen debe ser URL pública**: no se puede subir base64 directamente

## Verificar estado de publicación

```
GET https://graph.facebook.com/v18.0/{MEDIA_ID}
  fields=id,permalink,timestamp,like_count,comments_count
  access_token={INSTAGRAM_ACCESS_TOKEN}
```

## Output esperado

```
✅ Publicado en Instagram
Post ID: 17841234567891
URL: https://www.instagram.com/p/XXXXX/
Hora: 2026-02-27 09:15:32
```

En caso de error:
```
❌ Error publicando en Instagram
Código: 190
Mensaje: Invalid OAuth access token
Acción requerida: Renovar el access token en Meta Business Suite
El contenido fue guardado para publicación manual: .claude/posts/pending/2026-02-27.json
```

## Cómo renovar el token

Los tokens de larga duración duran ~60 días. Para renovar:
```
GET https://graph.facebook.com/oauth/access_token
  grant_type=fb_exchange_token
  client_id={APP_ID}
  client_secret={APP_SECRET}
  fb_exchange_token={TOKEN_ACTUAL}
```
O usar el [Token Debugger de Meta](https://developers.facebook.com/tools/debug/accesstoken/).
