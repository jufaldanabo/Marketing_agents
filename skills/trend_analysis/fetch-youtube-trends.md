# Skill: fetch-youtube-trends

**Propósito**: Consulta YouTube Data API v3 para encontrar los videos más vistos,
más comentados y con más reacciones sobre un tema en los últimos N días.
Soporta búsqueda general por tema y búsqueda acotada a canales de competidores.
**API**: YouTube Data API v3 (gratuita — cuota 10,000 units/día)
**Usado por**: `agents/trend-analyst-agent.md`, `commands/trend-ranking.md`

---

## Cuándo usar este skill

Usar para obtener datos estructurados de YouTube sobre tendencias de contenido
en un tema específico o en los canales de competidores configurados.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `topics` | list | Temas a buscar | `["confección industrial", "telas técnicas"]` |
| `lookback_days` | int | Días hacia atrás | `7` |
| `top_n` | int | Videos a recopilar por búsqueda | `15` |
| `YOUTUBE_API_KEY` | env | API key de Google Cloud | `AIzaSy...` |
| `competitors_yt` | list | Handles de canales (opcional) | `["@CanalA", "@CanalB"]` |

---

## Paso 1 — Calcular fecha límite

```bash
# macOS
FECHA_LIMITE=$(date -v-${LOOKBACK_DAYS}d +%Y-%m-%dT00:00:00Z)

# Linux
FECHA_LIMITE=$(date -d "-${LOOKBACK_DAYS} days" +%Y-%m-%dT00:00:00Z)
```

Ejemplo: si `LOOKBACK_DAYS=7` y hoy es `2026-07-25` → `publishedAfter=2026-07-18T00:00:00Z`

---

## Paso 2 — Búsqueda por tema

Para **cada tema** en `topics`, ejecutar los siguientes dos llamados en secuencia:

### 2a — Buscar videos (100 units por llamada)

```
GET https://www.googleapis.com/youtube/v3/search
  ?q={TOPIC_URL_ENCODED}
  &type=video
  &order=viewCount
  &publishedAfter={FECHA_LIMITE}
  &maxResults=15
  &part=snippet
  &relevanceLanguage=es
  &key={YOUTUBE_API_KEY}
```

De cada ítem en `items[]` extraer:
- `id.videoId`
- `snippet.title`
- `snippet.channelTitle`
- `snippet.channelId`
- `snippet.publishedAt`
- `snippet.description` (primeros 200 caracteres)

### 2b — Obtener estadísticas de los videos (1 unit por llamada)

Agrupar todos los `videoId` del paso anterior en una sola llamada (separados por coma):

```
GET https://www.googleapis.com/youtube/v3/videos
  ?id={ID1,ID2,ID3,...}
  &part=statistics,snippet,contentDetails
  &key={YOUTUBE_API_KEY}
```

De `items[].statistics` extraer:
- `viewCount` (puede ser null si el canal lo ocultó)
- `likeCount` (puede ser null)
- `commentCount` (puede ser null)

De `items[].contentDetails` extraer:
- `duration` (formato ISO 8601, ej. `PT8M32S` → convertir a `"8:32"`)

Conversión de duración ISO 8601:
- `PT1H2M3S` → `"1:02:03"`
- `PT8M32S` → `"8:32"`
- `PT45S` → `"0:45"`

---

## Paso 3 — Búsqueda por canales de competidores (opcional)

Solo ejecutar si `competitors_yt` no está vacío.

### 3a — Resolver handle a channelId (1 unit por llamada)

```
GET https://www.googleapis.com/youtube/v3/channels
  ?forHandle={HANDLE_SIN_ARROBA}
  &part=id,snippet
  &key={YOUTUBE_API_KEY}
```

Extraer `items[0].id` como `channelId`.
Si la respuesta está vacía o devuelve error → marcar competidor como `"channel_not_found"` y continuar.

### 3b — Buscar videos del canal (100 units por llamada)

```
GET https://www.googleapis.com/youtube/v3/search
  ?channelId={CHANNEL_ID}
  &type=video
  &order=viewCount
  &publishedAfter={FECHA_LIMITE}
  &maxResults=10
  &part=snippet
  &key={YOUTUBE_API_KEY}
```

Luego obtener estadísticas con el mismo endpoint del Paso 2b.

---

## Control de cuota

Estimar el uso antes de ejecutar:

```
Búsqueda por tema:    100 units × N_temas
Video details:          1 unit × (15 × N_temas)
Por competidor:       100 units (search) + 1 unit × 10 (details) = 110 units
─────────────────────────────────────────────────────
Ejemplo 2 temas + 2 competidores: 200 + 30 + 220 = ~450 units
Cuota disponible: 10,000 units/día
```

Si el acumulado supera las **9,000 units**, mostrar advertencia:
```
⚠️ Cuota YouTube casi agotada ({N}/10,000 units usadas).
   Deteniendo llamadas adicionales para esta ejecución.
   El análisis continuará con los datos recopilados hasta ahora.
```

---

## Manejo de errores HTTP

| Código | Causa | Acción |
|---|---|---|
| 403 `quotaExceeded` | Cuota del día agotada | Detener este skill, continuar con TikTok, registrar en `errors[]` |
| 403 `keyInvalid` | API key incorrecta o inactiva | Detener con mensaje de error claro. Sugerir: Google Cloud Console → Credentials |
| 400 `badRequest` | Parámetro inválido | Registrar en `errors[]`, continuar con el siguiente tema |
| 404 | channelId no encontrado | Marcar competidor como `"channel_not_found"`, continuar |
| Sin resultados (`items: []`) | Sin videos en el período para ese tema | Registrar en output, no es un error |

---

## Estructura de datos de salida (JSON)

```json
{
  "source": "youtube",
  "collected_at": "2026-07-25T08:15:00Z",
  "period": {
    "from": "2026-07-18T00:00:00Z",
    "to": "2026-07-25T00:00:00Z",
    "days": 7
  },
  "by_topic": [
    {
      "topic": "confección industrial",
      "videos": [
        {
          "video_id": "dQw4w9WgXcQ",
          "title": "Cómo optimizar tu taller de confección en 2026",
          "channel": "TextilPro Colombia",
          "channel_id": "UCxxxxxxxxxxxxxxxx",
          "published_at": "2026-07-20T14:00:00Z",
          "duration": "12:47",
          "stats": {
            "views": 847000,
            "likes": 12400,
            "comments": 890
          },
          "description_preview": "En este video aprenderás...",
          "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        }
      ],
      "videos_found": 15,
      "videos_with_stats": 14
    }
  ],
  "by_competitor": [
    {
      "handle": "@CanalA",
      "channel_id": "UCxxxxxxxxxxxxxxxx",
      "channel_name": "Canal A Oficial",
      "status": "ok",
      "videos": []
    },
    {
      "handle": "@CanalB",
      "channel_id": null,
      "channel_name": null,
      "status": "channel_not_found",
      "videos": []
    }
  ],
  "quota_used": 215,
  "errors": []
}
```

---

## Notas importantes

- `viewCount`, `likeCount`, `commentCount` pueden ser `null` si el canal ocultó
  sus métricas (YouTube permite esto). Registrar como `null` y señalarlo en el reporte
  final con la nota "métricas no disponibles (canal las ocultó)".

- `order=viewCount` en el endpoint de búsqueda ordena por relevancia ponderada,
  no garantiza orden estricto por vistas. Las estadísticas reales del Paso 2b son
  la fuente definitiva para construir los rankings.

- `relevanceLanguage=es` es una sugerencia al algoritmo, no un filtro estricto.
  Pueden aparecer videos en inglés si son muy relevantes. El skill `analyze-trend-content`
  filtra por relevancia sectorial en el paso de análisis.

- Para proyectos empresariales con mayor volumen, se puede solicitar cuota adicional
  gratuita en Google Cloud Console (requiere formulario de justificación).
