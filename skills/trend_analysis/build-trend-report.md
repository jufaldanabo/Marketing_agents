# Skill: build-trend-report

**Propósito**: Arma los 3 rankings de YouTube + ranking TikTok, integra los
análisis e ideas, y genera el reporte final en formato legible para el experto
de marketing y el JSON estructurado para uso posterior.
**Modelo**: `claude-sonnet-4-6`
**Usado por**: `agents/trend-analyst-agent.md`, `commands/trend-ranking.md`

---

## Cuándo usar este skill

Usar como último paso, después de todos los skills de recolección y análisis.
Recibe todos los datos procesados y produce los archivos de output finales.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `youtube_data` | dict | Output de fetch-youtube-trends |
| `tiktok_data` | dict | Output de fetch-tiktok-trends |
| `analyses` | dict | Output de analyze-trend-content |
| `ideas` | list | Output de generate-trend-ideas |
| `topics` | list | Lista de temas analizados |
| `company_context` | dict | Datos de company-context.json |
| `top_n` | int | Videos por ranking |
| `fecha_inicio` | string | Fecha de inicio del período (YYYY-MM-DD) |
| `fecha_fin` | string | Fecha de cierre del período (YYYY-MM-DD) |

---

## Paso 1 — Construir rankings de YouTube

Tomar todos los videos de `youtube_data.by_topic[]` y `by_competitor[]`.
Eliminar duplicados por `video_id`.

**Ranking 1 — Más vistos**: Ordenar por `stats.views` descendente. Tomar top_n.
**Ranking 2 — Más comentados**: Ordenar por `stats.comments` descendente. Tomar top_n.
**Ranking 3 — Más reacciones (likes)**: Ordenar por `stats.likes` descendente. Tomar top_n.

Reglas para videos con métricas null:
- Colocarlos al final del ranking con nota `"(métricas no disponibles — canal las ocultó)"`
- No omitirlos: pueden tener análisis de contenido valioso aun sin números

Un video puede aparecer en múltiples rankings. Señalarlo con el icono 🌟 en el reporte.

---

## Paso 2 — Construir ranking de TikTok

Combinar todos los videos de `tiktok_data.by_topic[]` y `by_competitor[]`.
Ordenar por `engagement_estimated.views` descendente (colocar nulls al final).
Separar por tema en el reporte.

---

## Paso 3 — Generar reporte en Markdown

Usar esta plantilla exacta para el archivo `.md`:

```
📊 TREND RANKING SEMANAL
Temas: {TOPICS_SEPARADOS_POR_BARRA} | {FECHA_INICIO_CORTA}–{FECHA_FIN_CORTA}
Empresa: {COMPANY_NAME} | Generado: {TIMESTAMP}
Fuentes: YouTube (API oficial) + TikTok (estimado vía WebSearch)

══════════════════════════════════════════════════
🏆 MÁS VISTOS — YouTube
══════════════════════════════════════════════════

#{N} {TITULO} {🌟 si aparece en otros rankings}
   @{CHANNEL} · {VIEWS} vistas · {LIKES} likes · {COMMENTS} comentarios · ⏱ {DURACION}
   📅 {FECHA_PUBLICACION} · 🔗 {URL}

   Por qué funcionó:
   {POR_QUE_FUNCIONO}

   IDEAS PARA {COMPANY_NAME}:
   → {TITULO_IDEA_1}
     Gancho: "{GANCHO_1}"
     Formato: {FORMATO_1}
     Dificultad: {DIFICULTAD_1} | Tiempo est.: {TIEMPO_1}

   → {TITULO_IDEA_2}
     Gancho: "{GANCHO_2}"
     Formato: {FORMATO_2}
     Dificultad: {DIFICULTAD_2} | Tiempo est.: {TIEMPO_2}

[Repetir para cada video en el ranking]

══════════════════════════════════════════════════
💬 MÁS COMENTADOS — YouTube
══════════════════════════════════════════════════

[Mismo formato — solo incluir análisis e ideas si el video NO apareció en ranking anterior]
[Si ya apareció: "#N {TITULO} 🌟 (ver ranking Más Vistos)"]

══════════════════════════════════════════════════
❤️ MÁS REACCIONES (LIKES) — YouTube
══════════════════════════════════════════════════

[Mismo formato]

══════════════════════════════════════════════════
📱 TOP TIKTOK
══════════════════════════════════════════════════
⚠️ Los datos de engagement de TikTok son estimados desde resultados de búsqueda web.
   No son cifras oficiales de TikTok API. Usar como referencia orientativa.

[TEMA: {TOPIC_1}]

#{N} {TITULO} — @{AUTHOR}
   ~{VIEWS_ESTIMADAS} vistas (estimado) · 🔗 {URL}

   Por qué funcionó:
   {POR_QUE_FUNCIONO}

   IDEAS PARA {COMPANY_NAME}:
   → {TITULO_IDEA}
     Gancho: "{GANCHO}"
     Formato: {FORMATO} (formato vertical, 30-90 seg)
     Dificultad: {DIFICULTAD} | Tiempo est.: {TIEMPO}

══════════════════════════════════════════════════
🧠 PATRONES DOMINANTES ESTA SEMANA
══════════════════════════════════════════════════

Los patrones más frecuentes entre los videos de mayor rendimiento:

1. {PATRON_1}: apareció en {N} de los {TOTAL} videos analizados
   Qué significa para tu contenido: {IMPLICACION_1_LINEA}

2. {PATRON_2}: apareció en {N} videos
   Qué significa: {IMPLICACION}

[Hasta 3 patrones dominantes]

══════════════════════════════════════════════════
📋 IDEAS ORDENADAS POR FACILIDAD DE PRODUCCIÓN
══════════════════════════════════════════════════

🟢 BAJA dificultad — ejecutables esta semana:
   • {TITULO_IDEA} ({PLATAFORMA}) — Tiempo: {TIEMPO}
   • {TITULO_IDEA} ({PLATAFORMA}) — Tiempo: {TIEMPO}

🟡 MEDIA dificultad — planificar para próximas 2 semanas:
   • {TITULO_IDEA} ({PLATAFORMA})

🔴 ALTA dificultad — incluir en planificación mensual:
   • {TITULO_IDEA} ({PLATAFORMA})

──────────────────────────────────────────────────
Fuentes: YouTube Data API v3 | TikTok via WebSearch + oEmbed
Período: {FECHA_INICIO} al {FECHA_FIN} ({LOOKBACK_DAYS} días)
Generado por Marketing Agents Toolkit — /trend-ranking
ℹ️ Para inteligencia de precios y competidores: /market-intel (lunes)
```

---

## Paso 4 — Generar JSON estructurado

```json
{
  "report_id": "trends-{FECHA_FIN}",
  "generated_at": "{TIMESTAMP_ISO}",
  "period": {
    "from": "{FECHA_INICIO_ISO}",
    "to": "{FECHA_FIN_ISO}",
    "days": 7
  },
  "topics": ["{TOPIC_1}", "{TOPIC_2}"],
  "company": "{COMPANY_NAME}",
  "rankings": {
    "youtube_most_viewed": [],
    "youtube_most_commented": [],
    "youtube_most_liked": [],
    "tiktok_top": []
  },
  "analyses": {},
  "ideas": [],
  "patterns_summary": [
    {
      "pattern": "tutorial_paso_a_paso",
      "frequency": 4,
      "platforms": ["youtube"],
      "implication": "El formato educativo con pasos numerados domina en este sector"
    }
  ],
  "ideas_by_difficulty": {
    "baja": [],
    "media": [],
    "alta": []
  },
  "sources": {
    "youtube": "YouTube Data API v3 (datos oficiales)",
    "tiktok": "WebSearch + TikTok oEmbed (engagement estimado)"
  },
  "quota_used": {
    "youtube_units": 215,
    "daily_quota": 10000
  }
}
```

---

## Paso 5 — Guardar archivos

```bash
# Reporte legible
Write ".claude/intel/trends-{FECHA_FIN}.md"

# Datos estructurados
Write ".claude/intel/trends-{FECHA_FIN}.json"
```

Crear el directorio `.claude/intel/` si no existe antes de escribir.

---

## Paso 6 — Preparar resumen para Telegram

Límite estricto: **4,096 caracteres** (límite de Telegram Bot API).

Plantilla del resumen (usar formato Markdown de Telegram: `*negrita*`, `_cursiva_`):

```
📊 *TREND RANKING SEMANAL — {COMPANY_NAME}*
📅 {FECHA_INICIO_CORTA} – {FECHA_FIN_CORTA} | _{TOPICS}_

══════════════════
🏆 TOP 3 MÁS VISTOS (YouTube)
══════════════════
1️⃣ _{TITULO_1}_ — @{CANAL}
   {VIEWS} vistas · ⏱ {DURACION}
   {POR_QUE_FUNCIONO_RESUMIDO_EN_1_LINEA}

2️⃣ _{TITULO_2}_ — @{CANAL}
   {VIEWS} vistas
   {POR_QUE_FUNCIONO_RESUMIDO}

3️⃣ _{TITULO_3}_ — @{CANAL}
   {VIEWS} vistas

══════════════════
📱 TOP 2 TIKTOK (estimado)
══════════════════
1️⃣ _{TITULO_TT_1}_ — @{AUTOR}
   ~{VIEWS_EST} vistas

2️⃣ _{TITULO_TT_2}_ — @{AUTOR}

══════════════════
💡 IDEAS PRIORITARIAS
══════════════════
🟢 _{IDEA_BAJA_1}_
   Gancho: "{GANCHO_1}"

🟢 _{IDEA_BAJA_2}_

🟡 _{IDEA_MEDIA_1}_

══════════════════
🧠 Patrón dominante: *{PATRON_DOMINANTE}*

_Reporte completo en .claude/intel/trends-{FECHA_FIN}.md_
```

Si el texto supera 4,096 caracteres:
1. Truncar primero la sección de ideas (mantener solo las 2 de menor dificultad)
2. Si aún supera: reducir rankings de TikTok a top 1
3. Mantener siempre: rankings YouTube top 3, patrón dominante, pie de página

---

## Output de este skill

```json
{
  "success": true,
  "files": {
    "markdown": ".claude/intel/trends-{FECHA}.md",
    "json": ".claude/intel/trends-{FECHA}.json"
  },
  "telegram_summary": "📊 *TREND RANKING...",
  "telegram_char_count": 1847,
  "stats": {
    "youtube_videos_analyzed": 15,
    "tiktok_videos_analyzed": 8,
    "ideas_generated": 12,
    "ideas_baja": 5,
    "ideas_media": 5,
    "ideas_alta": 2
  }
}
```
