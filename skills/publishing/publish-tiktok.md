# Skill: publish-tiktok

**Propósito**: Publica contenido en TikTok vía Content Posting API.
Soporta dos flujos: post de foto (automatizable) y video (requiere archivo local o URL).
**Modelo**: No requiere Claude — llama directamente a la TikTok API
**Usado por**: `/publish-today`, `/check-approvals`

---

## Variables de entorno requeridas

| Variable | Descripción |
|---|---|
| `TIKTOK_ACCESS_TOKEN` | Token OAuth 2.0 con scope `video.publish` |
| `TIKTOK_OPEN_ID` | open_id del usuario (se obtiene durante el auth flow) |

## Cómo obtener credenciales de TikTok

```
1. Ir a https://developers.tiktok.com/
2. Crear una app con product: "Content Posting API"
3. Agregar scopes: video.publish, video.list (para métricas)
4. Completar el OAuth 2.0 flow para obtener access_token + open_id
5. El access_token dura 24h — usar el refresh_token para renovar
   POST https://open.tiktokapis.com/v2/oauth/token/
     grant_type=refresh_token
     client_key={CLIENT_KEY}
     client_secret={CLIENT_SECRET}
     refresh_token={REFRESH_TOKEN}
```

**Nota**: TikTok requiere que la app sea aprobada para usar Content Posting API en producción.
En desarrollo, solo funciona con el creador de la app como usuario de prueba.

---

## FLUJO A — Post de foto (automatizable)

Ideal para: imágenes de producto, infografías, behind-the-scenes en foto.

### Paso A1 — Inicializar el post de foto

```
POST https://open.tiktokapis.com/v2/post/publish/content/init/
Headers:
  Authorization: Bearer {TIKTOK_ACCESS_TOKEN}
  Content-Type: application/json
Body:
{
  "post_info": {
    "title": "{CAPTION}",
    "privacy_level": "PUBLIC_TO_EVERYONE",
    "disable_duet": false,
    "disable_comment": false,
    "disable_stitch": false
  },
  "source_info": {
    "source": "PULL_FROM_URL",
    "photo_cover_index": 0,
    "photo_images": [
      "{URL_DE_LA_IMAGEN}"
    ]
  },
  "post_mode": "DIRECT_POST",
  "media_type": "PHOTO"
}
```

**Respuesta exitosa:**
```json
{
  "data": {
    "publish_id": "v_pub_url~tiktok-v2-7246834798..."
  },
  "error": {
    "code": "ok"
  }
}
```

### Paso A2 — Verificar estado del post

```
POST https://open.tiktokapis.com/v2/post/publish/status/fetch/
Headers:
  Authorization: Bearer {TIKTOK_ACCESS_TOKEN}
  Content-Type: application/json
Body:
{
  "publish_id": "{PUBLISH_ID}"
}
```

Verificar que `status` sea `PUBLISH_COMPLETE` (puede tardar 10-30 segundos).

---

## FLUJO B — Video (requiere archivo)

Para videos grabados por el negocio. El agente no puede grabar el video,
pero sí puede subir uno que ya existe localmente o via URL.

### Paso B1 — Inicializar upload del video

```
POST https://open.tiktokapis.com/v2/post/publish/video/init/
Headers:
  Authorization: Bearer {TIKTOK_ACCESS_TOKEN}
  Content-Type: application/json
Body:
{
  "post_info": {
    "title": "{DESCRIPTION_DEL_VIDEO}",
    "privacy_level": "PUBLIC_TO_EVERYONE",
    "disable_duet": false,
    "disable_comment": false,
    "disable_stitch": false,
    "video_cover_timestamp_ms": 1000
  },
  "source_info": {
    "source": "FILE_UPLOAD",
    "video_size": {TAMAÑO_EN_BYTES},
    "chunk_size": 10000000,
    "total_chunk_count": 1
  }
}
```

**Respuesta:**
```json
{
  "data": {
    "publish_id": "v_pub_url~...",
    "upload_url": "https://upload.tiktokapis.com/video/..."
  }
}
```

### Paso B2 — Subir el archivo de video

```
PUT {UPLOAD_URL}
Headers:
  Content-Range: bytes 0-{TAMAÑO-1}/{TAMAÑO}
  Content-Type: video/mp4
Body: [bytes del archivo de video]
```

### Paso B3 — Verificar estado

Igual que Paso A2 — verificar `status: "PUBLISH_COMPLETE"`.

---

## Manejo de errores comunes

| Error code | Significado | Solución |
|---|---|---|
| `access_token_invalid` | Token expirado o inválido | Renovar con refresh_token |
| `spam_risk_too_many_posts` | Límite de posts diarios alcanzado | Esperar 24h |
| `video_resolution_check_failed` | Video no cumple resolución mínima | Mínimo 720p |
| `photo_count_exceed_limit` | Demasiadas fotos en un post | Máximo 35 fotos |
| `unaudited_client_can_only_post_to_private_account` | App en desarrollo | Solo con cuenta de prueba o aprobar la app |

## Requisitos del contenido

**Para videos:**
- Formato: MP4, MOV, WEBM
- Resolución mínima: 720x1280 (vertical recomendado para mobile)
- Duración: 3 segundos a 10 minutos
- Tamaño máximo: 4GB

**Para fotos:**
- Formato: JPEG, PNG, WEBP
- Resolución mínima: 360x360
- Máximo 35 imágenes por post

## Output del skill

```json
{
  "platform": "tiktok",
  "format": "photo",
  "publish_id": "v_pub_url~tiktok-v2-7246834798...",
  "status": "PUBLISH_COMPLETE",
  "published_at": "2026-02-27T09:15:00",
  "caption": "500 porciones por hora. Esto no es artesanal, es industrial con alma.",
  "hashtags": ["#alimentos", "#produccion", "#pymes", "#fyp"],
  "saved_to": ".claude/posts/2026-02-27-tiktok.json"
}
```

## Nota sobre autonomía

En Railway (modo autónomo), el flujo de foto es **completamente automatizable**.

Para videos, el agente puede:
1. Detectar si hay un archivo `.mp4` o `.mov` en `.claude/pending-videos/`
2. Si existe → publicarlo con la descripción generada por `generate-tiktok-content.md`
3. Si no existe → guardar el guión en `.claude/drafts/` y notificar por Telegram:
   "📹 Guión listo para TikTok. Graba el video y súbelo a .claude/pending-videos/ para publicación automática."
