# Skill: fetch-tiktok-trends

**Propósito**: Encuentra videos virales de TikTok sobre un tema usando WebSearch
y enriquece los resultados con la API oEmbed de TikTok. No requiere credenciales
ni solicitud de aprobación.
**Herramientas**: WebSearch + WebFetch (oEmbed)
**Usado por**: `agents/trend-analyst-agent.md`, `commands/trend-ranking.md`

---

## Cuándo usar este skill

Usar para detectar tendencias de contenido en TikTok sin necesidad de API oficial.
Los datos de engagement son estimados desde snippets de búsqueda — siempre señalar
esto explícitamente en el output y en el reporte final.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `topics` | list | Temas a buscar | `["confección industrial"]` |
| `lookback_days` | int | Días hacia atrás (referencia para búsqueda) | `7` |
| `top_n` | int | Videos a recopilar por tema | `10` |
| `competitors_tt` | list | Usuarios de TikTok (opcional) | `["@usuario1", "@usuario2"]` |

---

## Paso 1 — Búsqueda web de videos TikTok

Para **cada tema** en `topics`, ejecutar las siguientes 4 búsquedas con WebSearch.
Usar el mes y año actual en las búsquedas para acotar resultados recientes.

```
Búsqueda 1: tiktok "{TOPIC}" {MES} {AÑO} millones vistas
Búsqueda 2: "{TOPIC}" tiktok viral {MES} {AÑO}
Búsqueda 3: site:tiktok.com "{TOPIC}"
Búsqueda 4: tiktok "{TOPIC}" tendencia {MES} {AÑO}
```

Ejemplo para tema `"confección industrial"` en julio 2026:
```
tiktok "confección industrial" julio 2026 millones vistas
"confección industrial" tiktok viral julio 2026
site:tiktok.com "confección industrial"
tiktok "confección industrial" tendencia julio 2026
```

### Qué extraer de los resultados de búsqueda

Para cada resultado que contenga una URL de TikTok con formato
`tiktok.com/@{usuario}/video/{id}`:

- URL completa del video
- Título o descripción visible en el snippet
- Nombre del creador si aparece
- Indicadores de engagement en el snippet (ej. `"2.3M vistas"`, `"847K likes"`)
- Fecha aproximada si aparece en el snippet

Ignorar URLs de TikTok que no sean videos individuales (perfiles, búsquedas, etc.).

---

## Paso 2 — Búsqueda por competidores (opcional)

Solo ejecutar si `competitors_tt` no está vacío.

Para cada usuario en la lista:

```
WebSearch: tiktok.com/@{USUARIO_SIN_ARROBA} videos recientes {MES} {AÑO}
WebSearch: "{USUARIO}" tiktok {MES} {AÑO} viral
```

Recolectar URLs de videos del usuario y procesarlas igual que el Paso 1.

---

## Paso 3 — Enriquecer con oEmbed API

Para cada URL de TikTok válida encontrada, hacer un WebFetch a:

```
GET https://www.tiktok.com/oembed?url={URL_DEL_VIDEO_CODIFICADA}
```

Ejemplo:
```
GET https://www.tiktok.com/oembed?url=https%3A%2F%2Fwww.tiktok.com%2F%40usuario%2Fvideo%2F7123456789012345678
```

Respuesta exitosa:
```json
{
  "version": "1.0",
  "type": "video",
  "title": "Así funciona una línea de confección industrial moderna #textil #confeccion",
  "author_name": "TextilPro",
  "author_url": "https://www.tiktok.com/@textilpro",
  "thumbnail_url": "https://p16-sign.tiktokcdn-us.com/...",
  "thumbnail_width": 720,
  "thumbnail_height": 1280,
  "provider_name": "TikTok",
  "provider_url": "https://www.tiktok.com"
}
```

Extraer: `title`, `author_name`, `author_url`, `thumbnail_url`.

### Manejo de errores oEmbed

| Respuesta | Causa | Acción |
|---|---|---|
| 404 | Video eliminado o URL inválida | Descartar video, continuar |
| 401 / 403 | Video privado | Descartar video, continuar |
| Timeout / error de red | Problema temporal | Reintentar una vez; si falla, usar solo datos del snippet |

---

## Paso 4 — Estimar engagement desde snippets

Los snippets de Google frecuentemente incluyen indicadores de popularidad.
Extraer usando estos patrones:

```
Patrones de vistas:   (\d+[\.,]?\d*)\s*(M|K|mil|millones)\s*(vistas|views|reproducciones)
Patrones de likes:    (\d+[\.,]?\d*)\s*(M|K|mil|millones)\s*(likes|me gusta|❤️)
```

Conversión de unidades:
- `2.3M` → `2_300_000`
- `847K` → `847_000`
- `2,3M` (formato español) → `2_300_000`
- `1.2 millones` → `1_200_000`

Si no se encuentran indicadores numéricos → registrar `null`.

**REGLA OBLIGATORIA**: Todos los valores de engagement de TikTok deben marcarse
con `"engagement_source": "estimated_from_search_snippet"`. Nunca presentar
estos números como datos oficiales.

---

## Estructura de datos de salida (JSON)

```json
{
  "source": "tiktok",
  "collected_at": "2026-07-25T08:30:00Z",
  "method": "websearch_oembed",
  "engagement_disclaimer": "Las métricas de TikTok son estimadas desde snippets de búsqueda web, no datos oficiales de TikTok API. Tratar como datos orientativos.",
  "by_topic": [
    {
      "topic": "confección industrial",
      "searches_performed": [
        "tiktok \"confección industrial\" julio 2026 millones vistas",
        "\"confección industrial\" tiktok viral julio 2026",
        "site:tiktok.com \"confección industrial\"",
        "tiktok \"confección industrial\" tendencia julio 2026"
      ],
      "videos": [
        {
          "url": "https://www.tiktok.com/@textilpro/video/7123456789012345678",
          "title": "Así funciona una línea de confección industrial moderna #textil",
          "author_name": "TextilPro",
          "author_url": "https://www.tiktok.com/@textilpro",
          "thumbnail_url": "https://p16-sign.tiktokcdn-us.com/...",
          "published_approx": "julio 2026",
          "engagement_estimated": {
            "views": 2300000,
            "likes": null,
            "comments": null,
            "engagement_source": "estimated_from_search_snippet"
          },
          "snippet_text": "Texto del snippet de búsqueda donde aparecieron los datos"
        }
      ],
      "videos_found": 8
    }
  ],
  "by_competitor": [],
  "errors": []
}
```

---

## Limitaciones documentadas

Incluir siempre estas limitaciones en el output (se mostrarán en el reporte final):

1. **Sin acceso a métricas reales**: TikTok Research API requiere aprobación del programa
   de investigadores. Sin ella, los números son aproximados o no disponibles.
2. **Videos privados y eliminados**: oEmbed falla silenciosamente. El video se descarta.
3. **Cobertura parcial**: WebSearch no indexa todos los videos de TikTok. Los resultados
   son una muestra sesgada hacia lo más viral o más reciente.
4. **Fechas aproximadas**: La fecha de publicación puede no estar disponible o ser imprecisa.

Estas limitaciones no invalidan el skill — su valor está en identificar patrones
de contenido y formatos que funcionan, no en reportar métricas exactas.
